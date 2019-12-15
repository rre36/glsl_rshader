#version 400 compatibility
#define DIM 1
#include "/lib/global.glsl"
#include "/lib/end/opt.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

const float minLight            = 0.01;
const vec3 minLightColor        = vec3(0.8, 0.9, 1.0);
const float lightLuma           = 1.0;
const vec3 lightColor           = vec3(1.0, 0.42, 0.0);


/* ------ buffer formats ------ */

const int colortex0Format   = RGB16F;
const int colortex1Format   = RGB16F;
const int colortex2Format   = RGB16;
const int colortex3Format   = RGBA16;
const int colortex4Format   = RGBA16F;
const int colortex5Format   = RG16F;
const int colortex6Format   = RGBA16;


/* ------ internal parameters ------ */

const float sunPathRotation = -12.5;

const float wetnessHalflife = 300.0;
const float drynessHalflife = 100.0;


/* ------ uniforms ------ */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform sampler2D depthtex1;

const bool shadowHardwareFiltering = true;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

uniform sampler2DShadow shadowcolor0;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform int frameCounter;

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;


/* ------ inputs from vertex stage ------ */

in vec2 coord;

flat in vec3 sunVector;
flat in vec3 moonVector;
flat in vec3 lightVector;
flat in vec3 upVector;

flat in float timeSunrise;
flat in float timeNoon;
flat in float timeSunset;
flat in float timeNight;
flat in float timeMoon;
flat in float timeLightTransition;
flat in float timeSun;

flat in vec3 colSunlight;
flat in vec3 colSkylight;
flat in vec3 colSky;
flat in vec3 colHorizon;


/* ------ structs ------ */

struct sceneData {
    vec3 albedo;
    vec3 normal;
    vec2 lightmap;
    vec4 sample2;
    vec4 sample3;
} scene;

struct depthData {
    float depth;
    float linear;
} depth;

struct positionData {
    vec3 camera;
    vec3 view;
    vec3 world;
} pos;

struct vectorData {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} vec;

struct shadingData {
    float diffuse;
    float shadow;
    float specular;
    float ao;
    float lit;
    float vanillaAo;

    vec3 shadowcolor;
    vec3 result;
    vec3 indirect;
} sdata;

struct lightData {
    vec3 sun;
    vec3 sky;
    vec3 artificial;
} light;

vec3 returnCol  = vec3(0.0);


/* ------ includes ------ */

#include "/lib/util/decode.glsl"
#include "/lib/util/decodeIn.glsl"
#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"
#include "/lib/util/encode.glsl"


/* ------ functions ------ */

vec3 unpackNormal(vec3 x) {
    return x*2.0-1.0;
}
void diffuseLambert(in vec3 normal) {
    normal          = normalize(normal);
    vec3 light      = normalize(vec.light);
    float lambert   = dot(normal, light);
        lambert     = max(lambert, 0.0);
    sdata.diffuse   = saturate(mix(lambert, 1.0, mat.foliage*0.7));
}

void specGGX(in vec3 normal) {
    float roughness = pow2(pbr.roughness);
    #ifdef s_usePBR
        float F0        = pbr.f0;
    #else
        float F0        = 0.08;
        if (pbr.metallic>0.5) {
            F0          = 0.2;
        }
    #endif
    vec3 h          = vec.light - vec.view;
    float hn        = inversesqrt(dot(h, h));
    float dotLH     = saturate(dot(h,vec.light)*hn);
    float dotNH     = saturate(dot(h,normal)*hn);
    float dotNL     = saturate(dot(normal,vec.light));  
    float denom     = (dotNH * roughness - dotNH) * dotNH + 1.0;
    float D         = roughness / (pi * denom * denom);
    float F         = F0 + (1.0 - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
    float k2        = 0.25 * roughness;

    sdata.specular  = dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
    
    #ifndef s_usePBR
        sdata.specular *= pbr.f0;
    #endif
    
    sdata.specular *= 1.0-rainStrength;
}

#include "/lib/shadow/warp.glsl"

float shadowFilter(in sampler2DShadow shadowtex, in vec3 wPos) {
    const float step = 1.0/shadowMapResolution;
    float noise     = ditherGradNoise()*pi;
    vec2 offset     = vec2(cos(noise), sin(noise))*step;
    float shade     = shadow2D(shadowtex, vec3(wPos.xy+offset, wPos.z)).x;
        shade      += shadow2D(shadowtex, vec3(wPos.xy-offset, wPos.z)).x;
        shade      += shadow2D(shadowtex, wPos.xyz).x*0.5;
    return shade*0.4;
}
vec4 shadowFilterCol(in sampler2DShadow shadowtex, in vec3 wPos) {
    const float step = 1.0/shadowMapResolution;
    float noise     = ditherGradNoise()*pi;
    vec2 offset     = vec2(cos(noise), sin(noise))*step;
    vec4 shade     = shadow2D(shadowtex, vec3(wPos.xy+offset, wPos.z));
        shade      += shadow2D(shadowtex, vec3(wPos.xy-offset, wPos.z));
        shade      += shadow2D(shadowtex, wPos.xyz)*0.5;
    return shade*0.4;
}

vec3 getShadowCoordinate2D(in vec3 screenpos, in float bias, out float distortion) {
	vec3 position 	= screenpos;
		position 	= viewMAD(gbufferModelViewInverse, position);
        position.y += bias;
		position 	= viewMAD(shadowModelView, position);
		position 	= projMAD(shadowProjection, position);
		position.z *= 0.2;

    distortion      = 1.0;
    warpShadowmap(position.xy, distortion);

	return position*0.5+0.5;
}

void getDirectLight(bool diffuseLit) {
    float bias          = 0.08;
    float distortion    = 0.0;
    vec3 viewpos        = pos.view;

    #ifdef temporalAA
        viewpos = getViewpos(depth.depth, taaJitter(gl_FragCoord.xy/vec2(viewWidth, viewHeight), -0.5));
    #endif

    vec3 scoord         = getShadowCoordinate2D(pos.view, bias, distortion);

    float shade         = 1.0;
    vec4 shadowcol      = vec4(1.0);
    bool translucencyShadow = false;

    if (diffuseLit) {
        shade       = shadowFilter(shadowtex1, scoord);
        shadowcol   = shadowFilterCol(shadowcolor0, scoord);

        float temp1 = shadowFilter(shadowtex0, scoord);

        translucencyShadow = temp1<shade;
    }

    sdata.shadow    = shade;
    sdata.shadowcolor = translucencyShadow ? mix(vec3(1.0), shadowcol.rgb, shadowcol.a) : vec3(1.0);
}

#ifdef setAmbientOcclusion
    #include "/lib/shadow/dbao.glsl"
#endif

float getLightmap(in float lightmap) {
    lightmap = linStep(lightmap, 1.0/24.0, 14.0/16.0);
    return pow3(lightmap);
}
vec3 artificialLight() {
    float lightmap      = getLightmap(scene.lightmap.x);
    vec3 lcol           = light.artificial;
    vec3 light          = mix(vec3(0.0), lcol, lightmap+mat.emissive*8.0);
    return light;
}

void applyShading() {
    vec3 indirectLight  = mix(light.sky, light.sun, saturate(s_shadowLuminance));

        indirectLight  += light.sun*sdata.indirect*(1.0-sdata.lit);

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = indirectLight+light.sun*sdata.shadowcolor*sdata.lit;
        directLight     = bLighten(directLight, artificial);

    vec3 metalCol       = scene.albedo*normalize(scene.albedo);

    float isMetal       = float(pbr.metallic>0.1);

    returnCol          *= 1.0-isMetal;

    sdata.result        = directLight*sdata.ao;
    returnCol          *= sdata.result;
    vec3 specular       = sdata.specular*light.sun*sdata.lit*mix(vec3(1.0), metalCol, isMetal);
    returnCol          += specular*sdata.shadowcolor;

    returnCol          += metalCol*isMetal*sdata.result;
}

void main() {
    scene.albedo    = texture(colortex0, coord).rgb;
    scene.normal    = unpackNormal(texture(colortex1, coord).rgb);
    scene.sample2   = texture(colortex2, coord);
    scene.lightmap  = scene.sample2.rg;
    scene.sample3   = texture(colortex3, coord);
    float sample4   = texture(colortex4, coord).a;

    decodeData();

    depth.depth     = texture(depthtex1, coord).x;
    depth.linear    = depthLin(depth.depth);

    pos.camera      = cameraPosition;
    pos.view        = getViewpos(depth.depth);
    pos.world       = toWorldpos(pos.view);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.view);

    sdata.shadow        = 1.0;
    sdata.diffuse       = 1.0;
    sdata.indirect      = vec3(0.0);
    sdata.ao            = 1.0;
    sdata.specular      = 0.0;
    sdata.shadowcolor   = vec3(1.0);
    sdata.vanillaAo     = flatten(pow2(sample4), 0.85);

    returnCol           = scene.albedo;

    if(mask.terrain) {
        light.sun       = colSunlight*sunlightLuma;
        light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
        light.sky       = colSkylight*skylightLuma;
        light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
        light.artificial = lightColor*lightLuma;


        float worldDistance = length(pos.world.xyz-pos.camera.xyz);
        float falloff       = 1.0-pow2(linStep(worldDistance, 100.0, 160.0));

        getDirectLight(sdata.diffuse>0.01);

        sdata.lit       = min(sdata.shadow, sdata.diffuse);
        
        #ifdef setAmbientOcclusion
            dbao(falloff);
        #endif

        sdata.ao    *= sdata.vanillaAo;

        applyShading();
    }

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
    gl_FragData[1]  = vec4(scene.sample3.r, encodeV3(scene.albedo), scene.sample3.b, 1.0);
}