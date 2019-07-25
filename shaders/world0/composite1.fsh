#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

const float sunlightLuma        = 5.5;
const float skylightLuma        = 0.1;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

const bool colortex0MipmapEnabled = true;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

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

struct reflectedVectorData {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} rvec;

struct reflectionData {
    vec4 sky;
    vec4 screen;
} ref;

struct lightData {
    vec3 sun;
    vec3 sky;
    float vDotL;
} light;

vec3 returnCol  = vec3(0.0);
bool translucency = false;
bool water = false;

#include "/lib/util/decode.glsl"
#include "/lib/util/decodeIn.glsl"
#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"

vec3 unpackNormal(vec3 x) {
    return x*2.0-1.0;
}

void ssr() {
    #if s_ssrQuality==0
        const int samples       = 20;
        const int maxRefinement = 4;
        const float stepSize    = 1.2;
        const float stepRefine  = 0.28;
        const float stepIncrease = 1.8;
    #elif s_ssrQuality==1
        const int samples       = 30;
        const int maxRefinement = 8;
        const float stepSize    = 1.2;
        const float stepRefine  = 0.28;
        const float stepIncrease = 1.8;
    #elif s_ssrQuality==2
        const int samples       = 30;
        const int maxRefinement = 10;
        const float stepSize    = 1.2;
        const float stepRefine  = 0.28;
        const float stepIncrease = 1.8;
    #endif

    float alpha     = 0.0;
    float roughness = pbr.roughness;
    float dither    = ditherDynamic;

    vec3 col        = vec3(0.0);
    vec3 rstart     = pos.screen;
    vec3 rdir       = normalize(rvec.view);
    vec3 rstep      = (stepSize+dither-0.5)*rdir;
    vec3 rpos       = rstart + rstep*dither;
    vec3 rprevpos   = rstart;
    vec3 rrefine    = rstep;

    int refine  = 0;
    vec3 pos    = vec3(0.0);
    float edge  = 0.0;

    for (int i = 0; i<samples; i++) {
        pos     = toVec3(gbufferProjection*toVec4(rpos))*0.5+0.5;

        if (pos.x<0.0 || pos.x>1.0 || pos.y<0.0 || pos.y>1.0 || pos.z<0.0 || pos.z>1.0) break;

        vec3 spos   = vec3(pos.xy, texture(depthtex0, pos.xy).x);
            spos    = toVec3(gbufferProjectionInverse*toVec4(spos*2.0-1.0));
        
        float dist  = distance(rpos, spos);

        if (dist < pow(length(rstep)*pow(length(rrefine), 0.11), 1.1)*1.22) {
            refine++;

            if (refine>=maxRefinement) break;

            rrefine -= rstep;
            rstep   *= stepRefine;
        }
        rstep       *= stepIncrease;
        rprevpos     = rpos;
        rrefine     += rstep;
        rpos         = rstart+rrefine;
    }

    if (pos.z < 1.0-1e-5) {
        if (water) edge = 1.0-pow10(saturate(coordDist(pos.xy)));
        else edge = 1.0-pow2(saturate(coordDist(pos.xy)));

        vec3 scene  = textureLod(colortex0, pos.xy, log2(viewWidth*10.0)*roughness).rgb;

        col         = scene;
        alpha       = edge;
    }
    ref.screen      = vec4(col, saturate(alpha));
}

#include "/lib/util/fresnel.glsl"

vec3 reflectedSky() {
    vec3 nFrag      = -rvec.view;
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

#include "/lib/nature/phase.glsl"

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

#if s_cloudMode==0
#include "/lib/nature/pcloud.glsl"
void reflect_cloud(inout vec3 scene) {
    const int samples       = s_vcSamples;

    vec3 wPos   = toWorldSpace(rvec.view*1024.0);
    vec3 wVec   = normalize(wPos-pos.camera.xyz);

    float height        = vc_altitude;

    vec3 lightColor     = mix(mix(colSunglow, vec3(0.0, 0.4, 1.0)*0.01, timeNight)*60.0, light.sky*30.5, timeLightTransition);
        lightColor     *= mix(vec3(1.0), vec3(1.1, 0.4, 0.3), timeSunrise+timeSunset*0.7);
    vec3 rayleighColor  = colSky*1.5;

    float cloud         = 0.0;
    float shading       = 1.0;
    float scatter       = 0.0;
    float distanceFade  = 1.0;
    float fadeFactor    = 1.0;
    const float transmittance = 1.0;

    float vDotL         = dot(vec.view, vec.light);

    bool isCloudVisible = false;

    if (!mask.terrain) {
        isCloudVisible = (wPos.y>=0 && 0<=height) || 
        (wPos.y<=0 && 0>=height);
    } else if (mask.terrain) {
        isCloudVisible = (wPos.y>=height && 0<=height) || 
        (wPos.y<=height && 0>=height);
    }

    if (isCloudVisible) {
        vec3 getPlane   = wVec*((height-pos.world.y)/wVec.y);
        vec3 stepPos    = pos.camera.xyz+getPlane;

        float dist = length(stepPos-pos.camera);

        float fade      = linStep(dist, 1000.0, 7000.0);

        if ((1.0-fade)>0.01) {
            float oD        = vc_shape(stepPos);

            if (oD>0.0) {
                float stepTransmittance = exp2(-oD*1.11*invLog2);

                cloud          += oD;

                vc_scatter(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);

                fadeFactor     -= (fade);
            }
        }
    }

    vec3 color          = mix(rayleighColor, lightColor, saturate(scatter));

    cloud               = saturate(cloud*pow2(fadeFactor));
    scene               = mix(scene, color*2.0, cloud);
}
#elif s_cloudMode==1
#include "/lib/nature/vcloud.glsl"
void reflect_cloud(inout vec3 scene) {
    const int samples       = 8;
    const float lowEdge     = vc_lowEdge;
    const float highEdge    = vc_highEdge;

    vec3 wPos   = toWorldSpace(rvec.view*1024.0);
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
            isCloudVisible = (wPos.y>=0 && 0<=height) || 
            (wPos.y<=0 && 0>=height);
        } else if (mask.terrain) {
            isCloudVisible = (wPos.y>=height && 0<=height) || 
            (wPos.y<=height && 0>=height);
        }

        if (isCloudVisible) {
            vec3 getPlane   = wVec*((height-pos.world.y)/wVec.y);
            vec3 stepPos    = pos.camera.xyz+getPlane;

            float dist = length(stepPos-pos.camera);

            float fade      = linStep(dist, 2000.0, 7000.0);

            if ((1.0-fade)>0.01) {
                float oD        = vc_shape(stepPos);

                if (oD>0.0) {
                    float stepTransmittance = exp2(-oD*1.11*invLog2);

                    cloud          += oD*weight;

                    vc_scatter(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);

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

    cloud               = saturate(cloud*fadeFactor);
    scene               = mix(scene, color*2.0, pow2(cloud));
}
#endif

void main() {
    scene.albedo    = textureLod(colortex0, coord, 0).rgb;
    scene.normal    = unpackNormal(texture(colortex1, coord).rgb);
    scene.sample2   = texture(colortex2, coord);
    scene.lightmap  = scene.sample2.rg;
    scene.sample3   = texture(colortex3, coord);

    decodeData();

    depth.depth     = texture(depthtex0, coord).x;
    depth.linear    = depthLin(depth.depth);
    depth.solid     = texture(depthtex1, coord).x;
    depth.solidLin  = depthLin(depth.solid);

    translucency = depth.solid>depth.depth;

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
    light.vDotL     = dot(rvec.view, vec.light);

    returnCol       = scene.albedo;
    vec3 reflectCol = vec3(0.0);

    water           = pbr.roughness < 0.01 && translucency;

    float roughnessFade = 1.0-linStep(pbr.roughness, 0.25, 0.5);
    float lightmapFade      = linStep(scene.lightmap.y, 0.66, 0.96);
        lightmapFade        = pow2(lightmapFade);

    if((mask.terrain || translucency) && roughnessFade>0.01 && isEyeInWater==0) {
        rvec.sun        = reflect(vec.sun, normalize(scene.normal));
        rvec.moon       = reflect(vec.moon, normalize(scene.normal));
        rvec.light      = reflect(vec.light, normalize(scene.normal));
        rvec.view       = reflect(vec.view, normalize(scene.normal));

        #ifdef s_ssr
            ssr();
        #endif

        float baseFresnel = getFresnel(scene.normal, vec.view, 2, false);

        float fresnel   = 1.0;
        vec3 metalFresnel = vec3(1.0);

        if (water) fresnel = pow3(linStep(baseFresnel, 0.0, 0.25))*0.98+0.02;
        else fresnel = max(pow2(linStep(baseFresnel, 0.0, 0.25)), pbr.f0)*0.5;

        reflectCol   = ref.screen.rgb;
        float reflectAlpha = ref.screen.a;

        vec3 albedoColor = decodeV3(scene.sample3.g);

        int metals      = int(pbr.metallic*255.0);

        #ifdef s_skyReflection
        if (water && reflectAlpha<1.0 && lightmapFade>0.0) {
            vec3 sky    = reflectedSky();

            #ifdef s_cloudReflection
                reflect_cloud(sky);
            #endif

            reflectCol  = mix(sky*lightmapFade, reflectCol, reflectAlpha);
            reflectAlpha = max(1.0*lightmapFade, reflectAlpha);
        }
        #endif

        if(metals >= 50 && metals <= 220) {
            mat2x3 metalNK = getMetalIOR(metals);
            metalFresnel = getComplexFresnel(metalNK[0], metalNK[1]);
            returnCol   *= 1.0-vec3avg(pow2(metalFresnel))*(reflectAlpha*0.9+0.1)*roughnessFade;
            reflectCol  *= pow2(metalFresnel)*reflectAlpha;
        } else if (metals > 220) {
            fresnel      = pow2(linStep(baseFresnel, 0.0, 0.25))*0.25+0.75;
            returnCol   *= mix(1.0, 1.0-fresnel, reflectAlpha);
            returnCol   *= mix(albedoColor, vec3(0.1), reflectAlpha);

            reflectCol  *= albedoColor*fresnel*reflectAlpha;
        } else {
            returnCol   *= mix(1.0, 1.0-fresnel, reflectAlpha);
            reflectCol  *= fresnel*reflectAlpha;
        }

        returnCol   += reflectCol;
    }

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
}