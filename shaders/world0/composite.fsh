#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

const float sunlightLuma        = 2.0;
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

vec3 unpackNormal(vec3 x) {
    return x*2.0-1.0;
}

vec3 skyVanilla = toLinear(skyColor)*0.8;
vec3 fogVanilla = toLinear(fogColor)*2.0;

vec3 skyGradient() {
    vec3 nFrag      = -normalize(screenSpacePos(depth.solid).xyz);
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

    float horizon   = linStep(horizonGrad, 0.15, 0.31);
        horizon     = pow6(horizon)*0.8;

    float sunGrad   = 1.0-dot(sgVec, nFrag);
    float moonGrad  = 1.0-dot(mgVec, nFrag);

    float sunGlow   = linStep(sunGrad, 0.7, 0.98);
        sunGlow     = pow3(sunGlow);

    float moonGlow  = pow(moonGrad*0.85, 15.0);
        moonGlow    = saturate(moonGlow*1.05)*0.8;

    vec3 sunLight   = colSunlight;
    vec3 moonColor  = vec3(0.55, 0.75, 1.0)*0.1;

    vec3 sky        = mix(skyVanilla, fogVanilla, horizonFade);
        sky         = mix(sky, fogVanilla, horizon);
        sky         = mix(sky, fogVanilla, lowDome);
        sky         = mix(sky, sunLight, sunGlow*1.0-timeNight);
        sky         = mix(sky, moonColor, moonGlow*timeNight);

    return sky;
}

void simpleFog() {
    vec3 fogVanilla = toLinear(fogColor)*2.0;
    
    float falloff   = saturate(length(pos.world.xyz-pos.camera)/far);
        falloff     = linStep(falloff, 0.35, 0.999);
        falloff     = pow2(falloff);
    
    vec3 skyCol     = falloff>0.0 ? skyGradient() : fogVanilla;

    returnCol       = mix(returnCol, skyCol, falloff);
}
void simpleFogEyeInWater() {
    vec3 fogVanilla = toLinear(fogColor)*2.0;

    vec3 wPosSolid  = worldSpacePos(depth.solid).xyz;
    vec3 wPos       = pos.world.xyz;
    float solidDistance = length(wPosSolid-pos.camera)/(far*0.8);
    float transDistance  = length(wPos-pos.camera)/(far*0.8);
    
    float falloff   = saturate(solidDistance-transDistance);
        falloff     = linStep(falloff, 0.35, 0.999);
        falloff     = pow2(falloff);
    
    vec3 skyCol     = falloff>0.0 ? skyGradient() : fogVanilla;

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

    vec3 fogCol     = (colSunlight*sunlightLuma+colSkylight*0.1)*vec3(0.1, 0.4, 1.0)*0.1;

    float caveFix   = isEyeInWater==1 ? 1.0 : linStep(eyeBrightnessSmooth.y/240.0, 0.0, 0.5);
    
    returnCol       = mix(returnCol, fogCol, falloff*caveFix);
}

void applyTranslucents() {
    vec4 translucents   = texture(colortex6, coord)*vec4(vec3(10.0), 1.0);
    returnCol       = mix(returnCol, translucents.rgb, translucents.a);
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

    returnCol       = scene.albedo;

    bool water = pbr.roughness < 0.01;


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