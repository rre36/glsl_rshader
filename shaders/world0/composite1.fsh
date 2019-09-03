#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D noisetex;

const bool colortex0MipmapEnabled = true;

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
uniform float eyeAltitude;
uniform float sunAngle;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
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

#include "/lib/nature/getSky.glsl"

vec3 cartToSphere(vec2 coord) {
    coord *= vec2(tau, pi);
    vec2 lon = sincos(coord.x) * sin(coord.y);
    return vec3(lon.x, cos(coord.y), lon.y);
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
void reflect_cloud(inout vec3 scene, in vec3 viewvec) {
    vec3 wPos   = toWorldpos(viewvec*1024.0);
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

    float vDotL         = dot(viewvec, vec.light);

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
void reflect_cloud(inout vec3 scenecol, in vec3 viewvec) {
    const int steps         = 6;
    const float density     = 0.022;
    const float lowEdge     = vc_lowEdge;
    const float highEdge    = vc_highEdge;

    /* --- calculate spheres --- */
    vec3 wvec       = mat3(gbufferModelViewInverse)*viewvec;
    vec2 psphere    = rsi((planetRadius+eyeAltitude)*vec.up, viewvec, planetRadius);
    bool visible    = !((eyeAltitude<lowEdge && psphere.y>0.0) || (eyeAltitude>highEdge && wvec.y>0.0));

    if (visible && mask.terrain) {
        vec2 bsphere    = rsi(vec3(0.0, 1.0, 0.0)*planetRadius+eyeAltitude, wvec, planetRadius+lowEdge);
        vec2 tsphere    = rsi(vec3(0.0, 1.0, 0.0)*planetRadius+eyeAltitude, wvec, planetRadius+highEdge);
    
        float startdist = eyeAltitude>highEdge ? tsphere.x : bsphere.y;
        float enddist   = eyeAltitude>highEdge ? bsphere.x : tsphere.y;

        vec3 startpos   = wvec*startdist;
        vec3 endpos     = wvec*enddist;

        startpos        = planetCurvePosition(startpos);
        endpos          = planetCurvePosition(endpos);

        float dither    = ditherDynamic;

        vec3 rstep      = (endpos-startpos)/steps;
        vec3 rpos       = rstep*dither + startpos + pos.camera;

        float rlength   = length(rstep);

        float scatter   = 0.0;
        float transmittance = 1.0;
        float cloud     = 0.0;
        float fade      = 1.0;
        float vDotL     = dot(viewvec, vec.light);

        vec3 sunlight   = mix(mix(colSunglow, vec3(0.0, 0.4, 1.0)*0.01, timeNight)*60.0, light.sky*30.5, timeLightTransition);
            sunlight   *= mix(vec3(1.0), vec3(1.1, 0.4, 0.3), timeSunrise+timeSunset*0.7);
        vec3 skylight   = colSky*1.5;

        for (int i = 0; i<steps; ++i, rpos += rstep) {
            float dist  = length(rpos-pos.camera);
            float dfade = linStep(dist, 1000.0, 7000.0);
            if (finv(dfade)<0.01) continue;
            
            float oD    = vc_shape(rpos)*rlength*density;
            if (oD <= 0.0) continue;

            cloud      += oD;
            float stepT = exp2(-oD*1.11*invLog2);

            fade       -= dfade*transmittance;

            #if s_vcLightingQuality==0
                vc_scatter(scatter, oD, rpos, 1.0, vDotL, transmittance, stepT);
            #elif s_vcLightingQuality==1
                vc_multiscatter(scatter, oD, rpos, 1.0, vDotL, transmittance, stepT);
            #endif

            transmittance *= stepT;
        }

        vec3 color  = mix(skylight, sunlight, saturate(scatter));
        cloud               = saturate(cloud);
        scenecol            = mix(scenecol, color, pow2(cloud)*pow3(fade));
    }
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
    pos.view        = getViewpos(depth.depth);
    pos.world       = toWorldpos(pos.view);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.view);

    light.sun       = colSunlight*sunlightLuma;
    light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
    light.sky       = mix(colSkylight, colSky*1.2, 0.66)*skylightLuma;
    light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
    light.vDotL     = dot(rvec.view, vec.light);

    returnCol       = scene.albedo;

    vec3 spherevec  = cartToSphere(coord)*vec3(1.0, 1.0, -1.0);
        spherevec   = mat3(gbufferModelView)*spherevec;

    vec3 skyref     = getSky(spherevec);

    #ifdef s_cloudReflection
        reflect_cloud(skyref, spherevec);
    #endif

    /*DRAWBUFFERS:4*/
    gl_FragData[0]  = makeSceneOutput(skyref);
}