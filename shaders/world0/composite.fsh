#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

const float sunlightLuma        = 5.5;
const float skylightLuma        = 0.1;

/* ------ uniforms ------ */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform int isEyeInWater;
uniform int worldTime;
uniform int frameCounter;

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform sampler2D noisetex;

const int noiseTextureResolution = 1024;


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
flat in vec3 colSunglow;

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
    float solid;
    float solidLin;
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

struct lightData {
    vec3 sun;
    vec3 sky;
    float vDotL;
} light;

vec3 returnCol  = vec3(0.0);
bool translucency = false;


/* ------ includes ------ */

#include "/lib/util/decode.glsl"
#include "/lib/util/decodeIn.glsl"
#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"
#include "/lib/util/encode.glsl"
#include "/lib/nature/phase.glsl"

vec3 unpackNormal(vec3 x) {
    return x*2.0-1.0;
}

vec3 skyGradientC() {
    vec3 nFrag      = -normalize(screenSpacePos(depth.depth).xyz);
    vec3 hVec       = normalize(-vec.up+nFrag);
    vec3 hVec2      = normalize(vec.up+nFrag);
    vec3 sgVec      = normalize(vec.sun+nFrag);
    vec3 mgVec      = normalize(vec.moon+nFrag);

    float hTop      = dot(hVec, nFrag);
    float hBottom   = dot(hVec2, nFrag);

    float horizonFade = linStep(hBottom, 0.3, 0.8);
        horizonFade = pow4(horizonFade)*0.75;

    float lowDome   = linStep(hBottom, 0.66, 0.71);
        lowDome     = pow3(lowDome);

    float horizonGrad = 1.0-max(hBottom, hTop);

    float horizon   = linStep(horizonGrad, 0.12, 0.31);
        horizon     = pow5(horizon)*0.8;

    float sunGrad   = 1.0-dot(sgVec, nFrag);
    float moonGrad  = 1.0-dot(mgVec, nFrag);

    float horizonGlow = saturate(pow2(sunGrad));
        horizonGlow = pow3(linStep(horizonGrad, 0.08-horizonGlow*0.1, 0.33-horizonGlow*0.05))*horizonGlow;
        horizonGlow = pow2(horizonGlow*1.3);
        horizonGlow = saturate(horizonGlow*0.75);

    float sunGlow   = linStep(sunGrad, 0.5, 0.98);
        sunGlow     = pow5(sunGlow);
        sunGlow    *= 1.0-timeNoon*0.8;

    float moonGlow  = pow(moonGrad*0.85, 15.0);
        moonGlow    = saturate(moonGlow*1.05)*0.8;

    vec3 sunColor   = colSunglow*2;
    vec3 sunLight   = colSunlight;
    vec3 moonColor  = vec3(0.55, 0.75, 1.0)*0.1;

    vec3 sky        = mix(colSky, colHorizon, horizonFade);
        sky         = mix(sky, colHorizon, horizon);
        sky         = mix(sky, colHorizon, lowDome);
        sky         = mix(sky, sunColor, saturate(sunGlow+horizonGlow)*(1.0-timeNight));
        sky         = mix(sky, moonColor, moonGlow*timeNight);

    return sky*3;
}

void simpleFog() {
    float falloff   = saturate(length(pos.world.xyz-pos.camera)/far);
        falloff     = linStep(falloff, s_fogStart*(1.0-timeSunrise*0.5), 0.999);
        falloff     = pow(falloff, s_fogExp);
    
    vec3 skyCol     = falloff>0.0 ? skyGradientC() : colHorizon;

    returnCol       = mix(returnCol, skyCol, falloff);
}

void simpleFogEyeInWater() {
    vec3 wPosSolid  = worldSpacePos(depth.solid).xyz;
    vec3 wPos       = pos.world.xyz;
    float solidDistance = length(wPosSolid-pos.camera)/(far*0.8);
    float transDistance  = length(wPos-pos.camera)/(far*0.8);
    
    float falloff   = saturate(solidDistance-transDistance);
        falloff     = linStep(falloff, s_fogStart*(1.0-timeSunrise*0.5), 0.999);
        falloff     = pow2(falloff);
    
    vec3 skyCol     = falloff>0.0 ? skyGradientC() : colHorizon;

    returnCol       = mix(returnCol, skyCol, falloff);
}

void underwaterFog() {
    vec3 wPosSolid  = worldSpacePos(depth.solid).xyz;
    vec3 wPos       = pos.world.xyz;

    float solidDistance = length(wPosSolid-pos.camera)/far16;
    float transDistance  = length(wPos-pos.camera)/far16;

    float falloff   = isEyeInWater==1 ? transDistance : solidDistance-transDistance;
        falloff     = saturate(falloff);
        falloff     = linStep(falloff, 0.0, 0.2);
        falloff     = 1.0-pow2(1.0-falloff);

    vec3 fogCol     = (colSunlight*sunlightLuma+colSkylight*0.1)*vec3(0.1, 0.4, 1.0)*0.05;

    float caveFix   = isEyeInWater==1 ? 1.0 : linStep(eyeBrightnessSmooth.y/240.0, 0.0, 0.5);
    
    returnCol       = mix(returnCol, fogCol, falloff*caveFix);
}

void applyTranslucents() {
    vec4 translucents   = texture(colortex6, coord)*vec4(vec3(10.0), 1.0);
    returnCol       = mix(returnCol, translucents.rgb, translucents.a);
}

float c_miePhase(float x) {
    float mie1  = mie(x, 0.8*0.8);
    float mie2  = mie(x, -0.5*0.8);
    return mix(mie2, mie1, 0.75);
}
float scatterIntegral(float transmittance, const float coeff) {
    float a   = -1.0/coeff;
    return transmittance * a - a;
}

const float vc_altitude     = s_vcAltitude;
const float vc_thickness    = s_vcThickness;
const float vc_lowEdge      = vc_altitude-vc_thickness/2;
const float vc_highEdge     = vc_altitude+vc_thickness/2;

#include "/lib/nature/vcloud.glsl"

void vcloud() {
    const int samples       = 12;
    const float lowEdge     = vc_lowEdge;
    const float highEdge    = vc_highEdge;

    vec3 wPos   = worldSpacePos(depth.solid).xyz;
    vec3 wVec   = normalize(wPos-pos.camera.xyz);

    bool isCorrectStepDir = pos.camera.y<vc_altitude;

    float heightStep    = vc_thickness/samples;
    float height;
    if (isCorrectStepDir) {
            height      = lowEdge;
            height     += heightStep*ditherDynamic;
    } else {
            height      = highEdge;
            height     -= heightStep*ditherDynamic;
    }

    vec3 lightColor     = mix(mix(colSunglow, vec3(0.0, 0.4, 1.0)*0.01, timeNight)*60.0, light.sky*30.5, timeLightTransition);
        lightColor     *= mix(vec3(1.0), vec3(1.1, 0.4, 0.3), timeSunrise+timeSunset*0.7);
    vec3 rayleighColor  = colSky*1.5;

    float cloud         = 0.0;
    float shading       = 1.0;
    float scatter       = 0.0;
    float distanceFade  = 1.0;
    float fadeFactor     = 1.0;
    float transmittance = 1.0;

    float weight        = 12.0/samples;

    float vDotL         = dot(vec.view, vec.light);

    bool isCloudVisible = false;

    for (int i = 0; i<samples; i++) {
        if (!mask.terrain) {
            isCloudVisible = (wPos.y>=pos.camera.y && pos.camera.y<=height) || 
            (wPos.y<=pos.camera.y && pos.camera.y>=height);
        } else if (mask.terrain) {
            isCloudVisible = (wPos.y>=height && pos.camera.y<=height) || 
            (wPos.y<=height && pos.camera.y>=height);
        }

        if (isCloudVisible) {
            vec3 getPlane   = wVec*((height-pos.camera.y)/wVec.y);
            vec3 stepPos    = pos.camera.xyz+getPlane;

            float dist = length(stepPos-pos.camera);

            float fade      = linStep(dist, 1000.0, 7000.0);

            if ((1.0-fade)>0.01) {
                float oD        = vc_shape(stepPos);

                if (oD>0.0) {
                    float stepTransmittance = exp2(-oD*1.11*invLog2);

                    cloud          += oD*weight;

                    #if s_vcLightingQuality==0
                        vc_scatter(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);
                    #elif s_vcLightingQuality==1
                        vc_multiscatter(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);
                    #endif

                    fadeFactor     -= (fade)*transmittance;

                    transmittance  *= stepTransmittance;
                }
            }
        }

        if (isCorrectStepDir) {
            height         += heightStep;
        } else {
            height         -= heightStep; 
        }
    }
    vec3 color          = mix(rayleighColor, lightColor, saturate(scatter));

    cloud               = saturate(cloud);
    returnCol           = mix(returnCol, color, pow2(cloud)*saturate(pow2(fadeFactor)));
}

void main() {
    scene.albedo    = texture(colortex0, coord).rgb;
    scene.normal    = unpackNormal(texture(colortex1, coord).rgb);
    scene.sample2   = texture(colortex2, coord);
    scene.sample3   = texture(colortex3, coord);

    decodeData();

    depth.depth     = texture(depthtex0, coord).x;
    depth.linear    = depthLin(depth.depth);
    depth.solid     = texture(depthtex1, coord).x;
    depth.solidLin  = depthLin(depth.solid);

    translucency = depth.solid>depth.depth;

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

    light.sun       = colSunlight*sunlightLuma;
    light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
    light.sky       = mix(colSkylight, colSky*1.2, 0.66)*skylightLuma;
    light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
    light.vDotL     = dot(vec.view, vec.light);

    returnCol       = scene.albedo;

    bool water = pbr.roughness < 0.01;

    vcloud();

    if (isEyeInWater==0 && (mask.terrain || translucency)) {
        if (water) underwaterFog();
        applyTranslucents();

        #ifdef setFog
            if (translucency) simpleFog();
        #endif
        
    } else if (isEyeInWater==1) {
        if (mask.terrain) simpleFogEyeInWater();
        applyTranslucents();
        underwaterFog();
    }


    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
}