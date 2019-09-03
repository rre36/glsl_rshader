#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

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
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

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

struct lightData {
    vec3 sun;
    vec3 sky;
} light;

vec3 returnCol  = vec3(0.0);
bool translucency = false;
float cloudAlpha = 0.0;

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

#include "/lib/nature/getSky.glsl"

void simpleFog() {
    float falloff   = saturate(length(pos.world.xyz-pos.camera)/far);
        falloff     = linStep(falloff, s_fogStart, 0.999);
        falloff     = pow(falloff, s_fogExp);
    
    vec3 skyCol     = falloff>0.0 ? getSky(vec.view) : colHorizon;

    returnCol       = mix(returnCol, skyCol, falloff);
}
void simpleFogEyeInWater() {
    vec3 wPosSolid  = getWorldpos(depth.solid);
    vec3 wPos       = pos.world;
    float solidDistance = length(wPosSolid-pos.camera)/(far*0.8);
    float transDistance  = length(wPos-pos.camera)/(far*0.8);
    
    float falloff   = saturate(solidDistance-transDistance);
        falloff     = linStep(falloff, 0.35, 0.999);
        falloff     = pow2(falloff);
    
    vec3 skyCol     = falloff>0.0 ? getSky(vec.view) : colHorizon;

    returnCol       = mix(returnCol, skyCol, falloff);
}

void underwaterFog() {
    vec3 wPosSolid  = getWorldpos(depth.solid).xyz;
    vec3 wPos       = pos.world;

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
    vec4 translucents   = texture(colortex6, coord)*vec4(vec3(20.0), 1.0);

    if (translucency) {
        vec3 translucentColor = saturate(normalize(translucents.rgb));
            translucentColor = mix(vec3(1.0), translucentColor, translucents.a);
        returnCol *= translucentColor;
    }
    
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

#if s_cloudMode==0

const float vc_altitude     = s_vcAltitude;
const float vc_thickness    = s_vcThickness;
const float vc_lowEdge      = vc_altitude-vc_thickness/2;
const float vc_highEdge     = vc_altitude+vc_thickness/2;

#include "/lib/nature/pcloud.glsl"

void pcloud() {
    vec3 wPos   = worldSpacePos(depth.depth).xyz;
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

                cloud          += oD;

                #if s_vcLightingQuality==0
                    vc_scatter(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);
                #elif s_vcLightingQuality==1
                    vc_multiscatter(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);
                #endif

                fadeFactor     -= (fade);
            }
        }
    }

    vec3 color          = mix(rayleighColor, lightColor, saturate(scatter));

    cloud               = saturate(cloud*pow2(fadeFactor));
    cloudAlpha          = cloud;
    returnCol           = mix(returnCol, color, cloud);
}

#elif s_cloudMode==1

const float vc_altitude     = s_vcAltitude;
const float vc_thickness    = s_vcThickness;
const float vc_lowEdge      = vc_altitude-vc_thickness/2;
const float vc_highEdge     = vc_altitude+vc_thickness/2;

#include "/lib/nature/vcloud.glsl"

void vcloud(inout vec3 scenecol) {
    const int steps         = s_vcSamples;
    const float density     = 0.022;
    const float lowEdge     = vc_lowEdge;
    const float highEdge    = vc_highEdge;

    vec3 wvec       = mat3(gbufferModelViewInverse)*vec.view;
    vec2 psphere    = rsi((planetRadius+eyeAltitude)*vec.up, vec.view, planetRadius);
    bool visible    = !((eyeAltitude<lowEdge && psphere.y>0.0) || (eyeAltitude>highEdge && wvec.y>0.0));

    if (visible && !(mask.terrain && eyeAltitude<lowEdge)) {
        vec2 bsphere    = rsi(vec3(0.0, 1.0, 0.0)*planetRadius+eyeAltitude, wvec, planetRadius+lowEdge);
        vec2 tsphere    = rsi(vec3(0.0, 1.0, 0.0)*planetRadius+eyeAltitude, wvec, planetRadius+highEdge);
    
        float startdist = eyeAltitude>highEdge ? tsphere.x : bsphere.y;
        float enddist   = eyeAltitude>highEdge ? bsphere.x : tsphere.y;

        vec3 startpos   = wvec*startdist;
        vec3 endpos     = wvec*enddist;

        float mrange    = (1.0-saturate((eyeAltitude-highEdge)*0.2)) * (1.0-saturate((lowEdge-eyeAltitude)*0.2));
            mrange      = mix(1.0, mrange, float(!mask.terrain));

        startpos        = mix(startpos, gbufferModelViewInverse[3].xyz, mrange);
        endpos          = mix(endpos, (pos.world-pos.camera)*(!mask.terrain ? (highEdge/64.0) : 1.0), mrange);

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
        float vDotL     = dot(vec.view, vec.light);

        vec3 sunlight   = mix(mix(colSunglow, vec3(0.0, 0.4, 1.0)*0.01, timeNight)*60.0, light.sky*30.5, timeLightTransition);
            sunlight   *= mix(vec3(1.0), vec3(1.1, 0.4, 0.3), (timeSunrise+timeSunset*0.7)*(1.0-rainStrength));
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


        vec3 color  = mix(skylight, sunlight, scatter);
        cloud               = saturate(cloud);
        cloudAlpha          = pow2(cloud)*pow3(fade);
        scenecol            = mix(scenecol, color, pow2(cloud)*pow3(fade));
    }
}
#endif

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

    pos.camera      = cameraPosition;
    pos.view        = getViewpos(depth.depth);
    pos.world       = toWorldpos(pos.view);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.view);

    returnCol       = scene.albedo;

    bool water = pbr.roughness < 0.006;

    #if s_cloudMode==0
        pcloud();
    #elif s_cloudMode==1
        vcloud(returnCol);
    #endif

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

    if (scene.sample3.r>0.75 && scene.sample3.r<0.95) returnCol *= 1.0-saturate(cloudAlpha)*0.9;

    #ifdef s_godrays
        vec4 translucentsample = texture(colortex6, coord);

        vec3 godrayColor    = mix(normalize(translucentsample.rgb), vec3(1.0), translucentsample.a);
            if (!translucency) godrayColor = vec3(1.0);

        float godrayAlpha = 1.0-float(mask.terrain);
            godrayAlpha *= 1.0-saturate(cloudAlpha);
            godrayAlpha *= 1.0-translucentsample.a;

        vec3 return6    = vec3(godrayAlpha)*godrayColor;
    #else
        vec3 return6 = vec3(0.0);
    #endif

    /*DRAWBUFFERS:06*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
    gl_FragData[1]  = vec4(return6, 1.0);
}