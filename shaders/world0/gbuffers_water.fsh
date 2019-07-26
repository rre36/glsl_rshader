#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float shadowIllumination  = 0.0;
const float sunlightLuma        = 5.5;
const float skylightLuma        = 0.1;
const float minLight            = 0.007;
const vec3 minLightColor        = vec3(0.8, 0.9, 1.0);
const float lightLuma           = 2.0;
const vec3 lightColor           = vec3(1.0, 0.26, 0.0);


/* ------ uniforms ------ */

uniform sampler2D tex;
uniform sampler2D noisetex;

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
    float specular;
    float metallic;
} pbr;

struct returnData{
    vec4 scene;
    vec2 lmap;
    float roughness;
    float specular;
    float metalness;
    float materials;
} rdata;


/* ------ includes ------ */

#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"
#include "/lib/util/encode.glsl"


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

    sdata.specular  = dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2)*(water==1 ? 0.9 : pbr.specular);
    sdata.specular *= 1.0-rainStrength;
}

void getDirectLightStatic(bool isLit) {
    if (isLit) {
    float skylightMap   = scene.lightmap.y;
    float lambert       = dot(scene.normal, vec.light);
        lambert         = max(lambert, 0.0);
        lambert         = lambert*0.5 + 0.5;
    sdata.shadow        = sstep(scene.lightmap.y, 0.93, 0.95)*lambert;
    sdata.indirect      = vec3(pow3(linStep(scene.lightmap.y, 0.66, 1.0))*0.5);
    }
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
    float shadowFade    = 1.0;

    vec3 wPosR          = vec3(0.0);
    vec3 wPos           = getShadowCoord(offset, canShadow, distortion, filterFix, distSqXZ, distSqY, shadowDistSq, cDepth, wPosR);

    float shade         = 1.0;
    vec4 shadowcol      = vec4(1.0);
    bool translucencyShadow = false;

    if (canShadow) {
        if (diffuseLit) {
            shadowFade      = min(1.0-distSqXZ/shadowDistSq, 1.0) * min(1.0-distSqY/shadowDistSq, 1.0);
            shadowFade      = saturate(shadowFade*2.0);

        shade       = shadowFilter(shadowtex1, wPos.xyz);

        shadowcol   = shadowFilterCol(shadowcolor0, wPos.xyz);

        float temp1 = shadowFilter(shadowtex0, wPos.xyz);

        translucencyShadow = temp1<shade;
        shadowcol.a *= shadowFade;
        }
    }

    sdata.shadow  = mix(1.0, shade, shadowFade);
    sdata.shadowcolor = translucencyShadow ? mix(vec3(1.0), shadowcol.rgb, shadowcol.a) : vec3(1.0);
}

float getLightmap(in float lightmap) {
    lightmap = 1-clamp(lightmap*1.1, 0.0, 1.0);
    lightmap *= 5.0;
    lightmap = 1.0 / pow2(lightmap+0.1);
    lightmap = sstep(lightmap, 0.025, 1.0);
    return lightmap;
}
vec3 artificialLight() {
    float lightmap      = getLightmap(scene.lightmap.x);
    vec3 lcol           = light.artificial;
    vec3 light          = mix(vec3(0.0), lcol, lightmap);
    return light;
}

void applyShading() {
    sdata.lightmap      = sstep(scene.lightmap.y, 0.15, 0.95);
    sdata.cave          = 1.0-sstep(scene.lightmap.y, 0.2, 0.5);

    vec3 indirectLight  = mix(sdata.skylight, light.sun, saturate(shadowIllumination));
        indirectLight   = mix(indirectLight, minLightColor*minLight, sdata.cave);

        indirectLight  += light.sun*sdata.indirect*(1.0-sdata.direct);

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = mix(indirectLight, light.sun*sdata.color, sdata.direct);
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

    float multi     = saturate((-dot(normalize(scene.normal), normalize(pos.screen)))*8.0)/sqrt(sqrt(max(vertexDist, 4.0)));

    return noise*multi*0.75;
}

vec3 parallaxCoord(vec3 coord) {
    vec3 fragPos    = pos.screen.xyz;
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
    inputSample.rgb    *= col.rgb;
    scene.albedo        = toLinear(inputSample.rgb);
    scene.normal        = nrm;
    scene.lightmap      = lmap;

    depth.depth         = gl_FragCoord.z;
    depth.linear        = depthLin(depth.depth);

    pbr.roughness       = water==1 ? 0.0001 : 0.25;
    pbr.specular        = 0.5;
    pbr.metallic        = 0.0;

    rdata.scene.rgb     = scene.albedo;
    rdata.scene.a       = inputSample.a;
    rdata.lmap          = lmap;
    rdata.materials     = 0.0;
    rdata.metalness     = pbr.metallic;
    rdata.roughness     = pbr.roughness;
    rdata.specular      = pbr.specular;

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

    pos.sun         = sunPosition;
    pos.moon        = moonPosition;
    pos.light       = shadowLightPosition;
    pos.up          = upPosition;
    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth, gl_FragCoord.xy/vec2(viewWidth, viewHeight));
    pos.world       = wpos.xyz;

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    light.sun       = colSunlight*sunlightLuma;
    light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
    light.sky       = colSkylight*skylightLuma;
    light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
    light.artificial = lightColor*lightLuma;

    if (water==1) {
        getWaterNormal();
        customWaterColor();
    }

    diffuseLambert(scene.normal);

    getDirectLight(sdata.diffuse>0.01);

    sdata.direct    = min(sdata.shadow, sdata.diffuse);
    sdata.color     = sdata.shadowcolor;

    if (sdata.direct>0.01) specGGX(scene.normal);
    sdata.specular *= sdata.direct;

    sdata.skylight  = light.sky;

    applyShading();

    if (water==0) rdata.scene.a = inputSample.a;
    //rdata.scene.a = mix(rdata.scene.a, 1.0, saturate(sdata.specular));

    //rdata.scene.rgb     = vec3(sdata.direct);
    //rdata.scene.a       = 1.0;

    /*DRAWBUFFERS:612*/
    gl_FragData[0] = makeSceneOutput(rdata.scene)*vec4(vec3(0.02), 1.0);
    gl_FragData[1] = toVec4(scene.normal*0.5+0.5);
    gl_FragData[2] = vec4(rdata.lmap, encodeV2(rdata.specular, rdata.roughness), 1.0);
    //gl_FragData[3] = vec4(0.25, rdata.materials, 0.0, 1.0);
    //gl_FragData[4] = vec4(vec3(0.0), col.a);
}