#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float minLight            = 0.01;
const vec3 minLightColor        = vec3(0.8, 0.9, 1.0);
const float lightLuma           = 1.0;
const vec3 lightColor           = vec3(1.0, 0.42, 0.0);

const int noiseTextureResolution = 1024;


/* ------ uniforms ------ */

uniform sampler2D tex;
uniform sampler2D noisetex;

#ifdef s_useNormal
    uniform sampler2D normals;
#endif

#ifdef s_usePBR
    uniform sampler2D specular;
#endif

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

const bool shadowHardwareFiltering = true;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

uniform sampler2DShadow shadowcolor0;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;


/* ------ inputs from vertex stage ------ */

in vec4 col;
in vec2 coord;
in vec2 lmap;

in vec3 wpos;

in float vertexDist;
in vec3 vertexViewVec;

flat in vec3 nrm;
flat in vec3 tangent;
flat in vec3 binormal;

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

flat in int water;


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
    float specular;
    float shadow;

    float direct;
    float ao;
    float cave;
    float lightmap;

    vec3 shadowcolor;
    vec3 color;
    vec3 indirect;
    vec3 skylight;

    vec3 result;
} sdata;

struct lightData {
    vec3 sun;
    vec3 sky;
    vec3 artificial;
} light;

struct pbrData {
    float roughness;
    float f0;
    float metallic;
    float emission;
    float ao;
} pbr;

struct returnData{
    vec4 scene;
    vec2 lmap;
    float roughness;
    float specular;
    float metalness;
    float materials;
} rdata;

float emissiveTex   = 0.0;
vec4 pbrSample      = vec4(0.0);
vec3 normalSample   = vec3(0.0);
float ao            = 1.0;


/* ------ includes ------ */

#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"
#include "/lib/util/encode.glsl"

vec3 flattenNormal(vec3 n) {
    const vec3 flatNormal = vec3(0.0, 0.0, 1.0);
    return mix(n, flatNormal, setNormalFlatten);
}

#define translucentPass

#include "/lib/labPBR.glsl"


/* ------ functions ------ */

void diffuseLambert(in vec3 normal) {
    normal          = normalize(normal);
    vec3 light      = normalize(vec.light);
    float lambert   = dot(normal, light);
        lambert     = max(lambert, 0.0);
    sdata.diffuse   = lambert;
}

void specGGX(in vec3 normal) {
    float roughness = pow2(pbr.roughness);
    if (water==1) roughness = 0.00002;
    float F0        = 0.08;
    if (pbr.metallic>0.5) {
        F0          = 0.2;
    }
    vec3 h          = vec.light - vec.view;
    float hn        = inversesqrt(dot(h, h));
    float dotLH     = saturate(dot(h,vec.light)*hn);
    float dotNH     = saturate(dot(h,normal)*hn);
    float dotNL     = saturate(dot(normal,vec.light));  
    float denom     = (dotNH * roughness - dotNH) * dotNH + 1.0;
    float D         = roughness / (pi * denom * denom);
    float F         = F0 + (1.0 - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
    float k2        = 0.25 * roughness;

    sdata.specular  = dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2)*(water==1 ? 0.9 : pbr.f0);
    sdata.specular *= 1.0-rainStrength;
}

#define shadowBias 0.12

#include "shadow/core.glsl"

float getLightmap(in float lightmap) {
    lightmap = linStep(lightmap, 1.0/24.0, 14.0/16.0);
    return pow3(lightmap);
}
vec3 artificialLight() {
    float lightmap      = getLightmap(scene.lightmap.x);
    vec3 lcol           = light.artificial;
    vec3 light          = mix(vec3(0.0), lcol, lightmap);
    return light;
}
void applyShading() {
    float lightmap      = sstep(scene.lightmap.y, 0.15, 0.95);
    float cave          = 1.0-sstep(scene.lightmap.y, 0.2, 0.5);

    vec3 indirectLight  = mix(sdata.skylight*lightmap, light.sun, saturate(s_shadowLuminance));
        indirectLight   = mix(indirectLight, minLightColor*minLight, cave);

        indirectLight  += light.sun*sdata.indirect*(1.0-sdata.direct);

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = indirectLight+light.sun*sdata.color*sdata.direct*finv(timeLightTransition);
        directLight     = bLighten(directLight, artificial);

    vec3 metalCol       = scene.albedo*normalize(scene.albedo);

    rdata.scene.rgb    *= 1.0-pbr.metallic;

    sdata.result        = directLight*sdata.ao;
    rdata.scene.rgb    *= sdata.result;
    vec3 specular       = sdata.specular*light.sun*sdata.direct*mix(vec3(1.0), metalCol, saturate(pbr.metallic*10.0));
    rdata.scene.rgb    += specular;

    rdata.scene.rgb    += metalCol*pbr.metallic*sdata.result;
}


float noise2D(in vec2 coord) {
    coord      /= 1024;
    return texture2D(noisetex, coord).x*2.0-1.0;
}

float getWaterHeight(in vec3 wpos, const bool pom) {
    float windAnim = -frameTimeCounter*1.5;
    vec2 windTemp = vec2(windAnim, 0.0);
    vec3 wind = vec3(windTemp.x, 0.5*windAnim, windTemp.y);

    vec3 rpos = wpos;
        rpos.y *= 0.2;

        rpos += noise2D((rpos.xz+rpos.y)*0.1+windTemp*0.02);

    float noise = noise2D(rpos.xz+rpos.y+windTemp);
        rpos *= 2.0;
        noise += noise2D(rpos.xz+rpos.y-windTemp)*0.5;
        rpos *= 2.0;
        noise += noise2D(rpos.xz+rpos.y+windTemp)*0.25;
        rpos *= 2.0;
        noise += noise2D(rpos.xz+rpos.y-windTemp)*0.125;
        rpos *= 2.0;
        noise += noise2D(rpos.xz+rpos.y+windTemp)*0.0625;

    float multi     = saturate((-dot(normalize(scene.normal), normalize(pos.view)))*8.0)/sqrt(sqrt(max(vertexDist, 4.0)));

    return noise*multi*0.75;
}

vec3 parallaxCoord(vec3 coord) {
    vec3 fragPos    = pos.view.xyz;
    vec3 viewVec    = vertexViewVec;
    vec3 rpos       = coord;
    const int samples = 6;
    const float weight = (1.0/samples)*0.5;
    //const float depth = weight;
    float distanceFade = length(pos.world-pos.camera);
        distanceFade = 1.0-linStep(distanceFade, 64.0, 96.0);
    float height    = (getWaterHeight(rpos, true))*weight*distanceFade;

    if (distanceFade>0.001) {
    for (int i = 0; i<samples; i++) {
        rpos.xz += height*(viewVec.xy)/vertexDist;
        height  = (getWaterHeight(rpos, true))*weight*distanceFade;
    }
    }
    rpos.xz += height*(viewVec.xy)/vertexDist;
    return rpos;
}

void getWaterNormal() {
    vec3 nrmOffset[4] = vec3[4] ( 
            vec3(-1.0, 0.0, 0.0),
            vec3(1.0, 0.0, 0.0),
            vec3(0.0, 0.0, 1.0),
            vec3(0.0, 0.0, -1.0)
        );

    mat3 tbnMatrix = mat3(tangent.x, binormal.x, nrm.x,
				tangent.y, binormal.y, nrm.y,
				tangent.z, binormal.z, nrm.z);

    float nrmSampleSize = 0.014;
        nrmSampleSize += saturate(vertexDist/32.0-0.25)*0.25;

    vec3 position   = parallaxCoord(wpos.xyz);
    //vec3 position   = wpos.xyz;

    float h0 = getWaterHeight(position, false);
    float hL = getWaterHeight(position+vec3(nrmOffset[0]*nrmSampleSize), false);
    float hR = getWaterHeight(position+vec3(nrmOffset[1]*nrmSampleSize), false);
    float hU = getWaterHeight(position+vec3(nrmOffset[2]*nrmSampleSize), false);
    float hD = getWaterHeight(position+vec3(nrmOffset[3]*nrmSampleSize), false);

    vec3 wNormalNoise;
        wNormalNoise.x  = -((hL-h0)+(h0-hR))/nrmSampleSize;
        wNormalNoise.y  = -((hU-h0)+(h0-hD))/nrmSampleSize;
        wNormalNoise.z  = 1.0-pow2(wNormalNoise.x)-pow2(wNormalNoise.y);

    vec3 normal = wNormalNoise;

    normal = mix(normal, vec3(0.0, 0.0, 1.0), 0.99);
    normal = clamp(normalize(normal*tbnMatrix), -1.0, 1.0);

    scene.normal = normal;
}

void customWaterColor() {
    float baseFresnel = getFresnel(scene.normal, vec.view, 2, false);

    float brightness  = s_waterLuma;

    vec3 watercolor     = vec3(s_waterR, s_waterG, s_waterB)*brightness;
    float opacity       = s_waterOpacity;

    rdata.scene.rgb = watercolor;
    rdata.scene.a   = opacity;
}

void main() {
vec4 inputSample        = texture(tex, coord);

    #ifdef s_useNormal
        normalSample = texture(normals, coord).rgb;
    #endif

    #ifdef s_usePBR
        pbrSample = texture(specular, coord);
        if (water==1) pbr.roughness = 0.0001;
    #else
        pbr.roughness       = water==1 ? 0.0001 : 0.25;
        pbr.f0              = 0.05;
        pbr.metallic        = 0.0;
    #endif

    inputSample.rgb    *= col.rgb;
    scene.albedo        = toLinear(inputSample.rgb);
    scene.normal        = nrm;
    scene.lightmap      = lmap;

    depth.depth         = gl_FragCoord.z;
    depth.linear        = depthLin(depth.depth);

    rdata.scene.rgb     = scene.albedo;
    rdata.scene.a       = inputSample.a;
    rdata.lmap          = lmap;
    rdata.materials     = 0.0;

    sdata.shadow        = 1.0;
    sdata.diffuse       = 1.0;
    sdata.specular      = 0.0;
    sdata.ao            = flatten(col.a, 0.85);

    sdata.direct        = 1.0;
    sdata.indirect      = vec3(0.0);
    sdata.specular      = 0.0;
    sdata.shadowcolor   = vec3(1.0);
    sdata.color         = vec3(1.0);
    sdata.skylight      = vec3(0.0);
    sdata.result        = vec3(0.0);

    pos.camera      = cameraPosition;
    pos.view        = getViewpos(depth.depth, gl_FragCoord.xy/vec2(viewWidth, viewHeight));
    pos.world       = toWorldpos(pos.view);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.view);

    light.sun       = colSunlight*sunlightLuma;
    light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
    light.sky       = colSkylight*skylightLuma;
    light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
    light.artificial = lightColor*lightLuma;

    if (water==1) {
        getWaterNormal();
        customWaterColor();
    }

    #ifdef s_useNormal
        if (water==0) getLabNormal();
    #endif

    #ifdef s_usePBR
        if (water==0) getLabPbr();
    #endif

    diffuseLambert(scene.normal);

    getDirectLight(sdata.diffuse>0.01);

    sdata.direct    = min(sdata.shadow, sdata.diffuse);
    sdata.color     = sdata.shadowcolor;

    if (sdata.direct>0.01) specGGX(scene.normal);
    sdata.specular *= sdata.direct;

    sdata.skylight  = light.sky;

    applyShading();

    #ifdef s_usePBR
        if (water==0) pbr.roughness = max(pbr.roughness, sqrt(0.007));
    #endif

    rdata.metalness     = pbr.metallic;
    rdata.roughness     = pbr.roughness;
    rdata.specular      = pbr.f0;

    //rdata.scene.rgb     = vec3(sdata.direct);
    //rdata.scene.a       = 1.0;

    /*DRAWBUFFERS:612*/
    gl_FragData[0] = makeSceneOutput(rdata.scene)*vec4(vec3(0.05), 1.0);
    gl_FragData[1] = toVec4(scene.normal*0.5+0.5);
    gl_FragData[2] = vec4(rdata.lmap, encodeV2(rdata.specular, rdata.roughness), 1.0);
    //gl_FragData[3] = vec4(0.25, rdata.materials, 0.0, 1.0);
    //gl_FragData[4] = vec4(vec3(0.0), col.a);
}