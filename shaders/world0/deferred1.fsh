#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"


/* ------ buffer formats ------ */

const int colortex0Format   = R11F_G11F_B10F;
const int colortex1Format   = RGB16F;
const int colortex2Format   = RGB16;
const int colortex3Format   = RGBA16;
const int colortex4Format   = RGBA16F;
const int colortex5Format   = RG16F;
const int colortex6Format   = RGBA16;


/* ------ internal parameters ------ */

const float sunPathRotation = -17.5;

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

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
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

flat in float timeNoon;


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
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 camera;
    vec3 screen;
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
    float specular;
    float shadow;
    float ao;
    float lit;
    float vanillaAo;

    vec3 shadowcolor;
    vec3 result;
    vec3 gi;
} sdata;

struct returnData {
    float directLight;
    float ao;
    float specular;

    vec3 indirect;
    vec3 shadowColor;
} rdata;


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

vec3 getShadowCoord(in float offset, out bool canShadow, out float distortion, out float filterFix, out float distSqXZ, out float distSqY, out float shadowDistSq, out float cDepth, out vec3 wPosR) {
    float dist      = length(pos.screen.xyz);
    vec3 wPos       = vec3(0.0);
    canShadow       = false;
    distortion      = 0.0;
    distSqXZ        = 0.0;
    distSqY         = 0.0;
    shadowDistSq    = 0.0;
    cDepth          = 0.0;
    offset         *= 3072.0/shadowMapResolution;

    if (dist > 0.05) {
        shadowDistSq    = pow2(shadowDistance);
        wPos            = pos.screen;

        #ifdef temporalAA
            wPos        = screenSpacePos(depth.depth, taaJitter(gl_FragCoord.xy/vec2(viewWidth, viewHeight), -0.5));
        #endif

        wPos.xyz       += vec3(offset)*vec.light;
        wPos.xyz        = viewMAD(gbufferModelViewInverse, wPos.xyz);
        distSqXZ        = pow2(wPos.x) + pow2(wPos.z);
        distSqY         = pow2(wPos.y);

            wPos.xyz            = viewMAD(shadowModelView, wPos.xyz);
            wPosR               = wPos;
            wPos.xyz            = projMAD(shadowProjection, wPos.xyz);
            warpShadowmap(wPos.xy, distortion);
            filterFix           = 1.0/distortion;
            wPos.z             *= 0.2;
            wPos.xyz            = wPos.xyz*0.5+0.5;

            canShadow   = true;
    }
    return wPos;
}

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

void getDirectLight(bool diffuseLit) {
    float offset    = 0.08;

    bool canShadow      = false;
    float distortion    = 0.0;
    float filterFix     = 0.0;
    float distSqXZ      = 0.0;
    float distSqY       = 0.0;
    float shadowDistSq  = 0.0;
    float cDepth        = 0.0;
    float shadowFade    = 0.0;

    vec3 wPosR          = vec3(0.0);
    vec3 wPos           = getShadowCoord(offset, canShadow, distortion, filterFix, distSqXZ, distSqY, shadowDistSq, cDepth, wPosR);

    float shade         = 1.0;
    vec4 shadowcol      = vec4(1.0);
    bool translucencyShadow = false;

    if (canShadow) {
        if (diffuseLit) {

        shade       = shadowFilter(shadowtex1, wPos.xyz);

        shadowcol   = shadowFilterCol(shadowcolor0, wPos.xyz);

        float temp1 = shadowFilter(shadowtex0, wPos.xyz);

        translucencyShadow = temp1<shade;
        }
    }

    float staticShade   = 1.0;
    float staticFade    = 1.0-timeNoon;

    sdata.shadow    = shade;
    sdata.shadowcolor = translucencyShadow ? mix(vec3(1.0), shadowcol.rgb, shadowcol.a) : vec3(1.0);
}

#ifdef setAmbientOcclusion
    #include "/lib/shadow/dbao.glsl"
#endif

void main() {
    scene.albedo    = texture(colortex0, coord).rgb;
    scene.normal   = unpackNormal(texture(colortex1, coord).rgb);
    scene.sample2   = texture(colortex2, coord);
    scene.lightmap  = scene.sample2.rg;
    scene.sample3   = texture(colortex3, coord);
    float sample4   = texture(colortex4, coord).a;

    decodeData();

    depth.depth     = texture(depthtex1, coord).x;
    depth.linear    = depthLin(depth.depth);

    pos.sun         = sunPosition;
    pos.moon        = moonPosition;
    pos.light       = shadowLightPosition;
    pos.up          = upPosition;
    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth);
    pos.world       = worldSpacePos(depth.depth);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    sdata.shadow        = 1.0;
    sdata.diffuse       = 1.0;
    sdata.gi            = vec3(0.0);
    sdata.ao            = 1.0;
    sdata.specular      = 0.0;
    sdata.shadowcolor   = vec3(1.0);
    sdata.vanillaAo     = flatten(pow2(sample4), 0.85);

    if(mask.terrain) {
        float worldDistance = length(pos.world.xyz-pos.camera.xyz);
        float falloff       = 1.0-pow2(linStep(worldDistance, 100.0, 160.0));

        if (scene.sample3.r>0.26 && scene.sample3.r<0.28) sdata.diffuse = 1.0;
        else diffuseLambert(scene.normal);

        getDirectLight(sdata.diffuse>0.01);

        sdata.lit       = min(sdata.shadow, sdata.diffuse);

        if (sdata.lit>0.01) specGGX(scene.normal);
        sdata.specular *= sdata.lit;
        
        #ifdef setAmbientOcclusion
            dbao(falloff);
        #endif
    }

    rdata.directLight   = sdata.lit;
    rdata.ao            = sdata.ao*sdata.vanillaAo;
    rdata.indirect      = sdata.gi*0.3;
    rdata.specular      = sdata.specular;
    rdata.shadowColor   = saturate(sdata.shadowcolor);

    /*DRAWBUFFERS:345*/
    gl_FragData[0]  = max(vec4(scene.sample3.rgb, encodeV3(rdata.shadowColor)), 0.0);
    gl_FragData[1]  = vec4(rdata.indirect, rdata.ao);
    gl_FragData[2]  = max(vec4(rdata.directLight, rdata.specular/8.0, 0.0, 1.0), 0.0);
}