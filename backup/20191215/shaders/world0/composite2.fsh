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
    vec3 rstart     = pos.view;
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
        edge        = 1.0-pow10(saturate(coordDist(pos.xy)));

        vec3 scene  = textureLod(colortex0, pos.xy, log2(viewWidth*10.0)*roughness).rgb;

        col         = scene;
        alpha       = edge;
    }
    ref.screen      = vec4(col, saturate(alpha*2.0));
}

    vec3 skyVanilla = toLinear(skyColor)*0.8;
    vec3 fogVanilla = toLinear(fogColor)*2.0;
#include "/lib/nature/getSky.glsl"

#include "/lib/util/fresnel.glsl"

#ifdef s_godrays
void godrays() { 
    vec3 sunPos;
    vec3 sunVec;
    if (sunAngle>0.5) {
        sunPos     = moonPosition;
        sunVec     = vec.moon;
    } else {
        sunPos     = sunPosition;
        sunVec     = vec.sun;
    }

    float sDotU = dot(vec.sun, vec.up);
    float svisible = sqr(clamp(sDotU+0.1, 0.0, 0.1)/0.1);
    float mDotU = dot(vec.moon, vec.up);
    float mvisible = sqr(clamp(mDotU+0.1, 0.0, 0.1)/0.1);

    const int samples = s_godraySamples;

    vec3 nFrag      = -vec.view;
    vec3 sgVec      = normalize(sunVec+nFrag);
    float sunGrad   = 1.0-dot(sgVec, nFrag);
    float sunGlow   = linStep(sunGrad, 0.2, 0.98);
        sunGlow     = sqr(sunGlow);
    
    if (sunGlow>0.0) {
        vec4 tpos   = vec4(sunPos, 1.0)*gbufferProjection;
            tpos    = vec4(tpos.xyz/tpos.w, 1.0);
            tpos.xy = tpos.xy/tpos.z;
        vec2 lightpos = tpos.xy*0.5+0.5;
        float truepos = sunPos.z/abs(sunPos.z);

        float sunpos = abs(dot(vec.view, sunVec));
        float decay  = pow(sunpos, 30.0)+pow(sunpos, 16.0)*0.8+sqr(sunpos)*0.125;

        vec2 deltacoord = (lightpos-coord)*s_godrayLength;
            deltacoord *= 1.0/samples;
        vec2 tcoord     = coord-deltacoord*ditherDynamic;

        vec3 godrays   = vec3(0.0);

        if (decay>0.0 && truepos<1.0) {
            for (int i = 0; i<samples; i++) {
                tcoord += deltacoord;
                //if (tcoord.x<0.0 || tcoord.x>1.0 || tcoord.y<0.0 || tcoord.y>1.0) break;

                vec3 temp = textureLod(colortex6, saturate(tcoord), 1).rgb;
                godrays += temp*(1.0-sqr(float(i)/samples));
            }
            godrays /= 8.0;
            godrays *= decay*sunGlow;
        }

        vec3 lightcol = mix(light.sun, colSunglow*2.0, timeNight);

        returnCol += godrays*lightcol*0.5*s_godrayStrength*(1.0-timeLightTransition)*(1.0-rainStrength*0.9);
    }
}
#endif

void simpleFog(inout vec3 returnCol, in float multi) {
    vec3 fogVanilla = toLinear(fogColor)*2.0;
    
    float falloff   = saturate(length(pos.world-pos.camera)/far);
        falloff     = linStep(falloff, 0.35, 0.999);
        falloff     = sqr(falloff);
    
    vec3 skyCol     = falloff>0.0 ? getSky(vec.view) : fogVanilla;

    returnCol       = mix(returnCol, skyCol*multi, falloff);
}

vec2 sphereToCart(vec3 dir) {
    vec2 lonlat = vec2(atan(-dir.x, dir.z), acos(dir.y));
    return lonlat * vec2(1.0/tau, 1.0/pi) + vec2(0.5, 0.0);
}

#define HASHSCALE4 vec4(443.897, 441.423, 437.195, 444.129)
vec4 hash42(in float i) {
    vec2 p  = pos.view.xy+frameCounter%8-i;
	vec4 p4 = fract(p.xyxy * HASHSCALE4);
	p4 += dot(p4, p4.wzxy + 19.19);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx)-0.5;
}
vec3 roughNormal(in vec4 dither, in float roughness, in vec3 normal) {
    dither.xyz  = normalize(cross(normal, dither.xyz));
    return normalize(dither.xyz * (roughness*dither.w/(1.0-dither.w))+normal);
}

vec3 getSkyref(in vec3 viewvec, in vec3 normal, const int steps) {
    //vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    //mat3 tbn    = mat3(tangent, cross(normal, tangent), normal);
    float rstep = 1.0/steps;

    vec3 refcol = vec3(0.0);

    for (int i = 0; i<steps; ++i) {

        vec3 rnormal = vec3(0.0, 0.0, 1.0);
        
        if (pbr.roughness>0.002) rnormal = roughNormal(hash42(float(i)*rstep), pbr.roughness, normal);
        else rnormal = normal;
        vec3 rvec   = reflect(viewvec, rnormal);
        vec3 rvecw  = mat3(gbufferModelViewInverse)*rvec;

        vec2 spherecoord = sphereToCart(rvecw);
        vec3 sky    = texture(colortex4, spherecoord).rgb;
        refcol += sky;
    }
    refcol *= rstep;

    return refcol;
}

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
    vec3 reflectCol = vec3(0.0);

    water           = pbr.roughness < 0.006 && translucency;

    #if (defined s_ssr || defined s_skyReflection)
        float roughnessFade = 1.0-linStep(pbr.roughness, 0.25, 0.5);
        float lightmapFade      = linStep(scene.lightmap.y, 0.66, 0.96);
            lightmapFade        = sqr(lightmapFade);

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

            if (water) fresnel = sqr(linStep(baseFresnel, 0.0, 0.25))*0.96+0.04;
            else fresnel = pow4(linStep(baseFresnel, 0.0, 0.25))*finv(pbr.f0)+pbr.f0;

            reflectCol   = ref.screen.rgb;
            float reflectAlpha = ref.screen.a;

            vec3 albedoColor = decodeV3(scene.sample3.g);

            int metals      = int(pbr.metallic*255.0);

            #ifdef s_skyReflection
            if (reflectAlpha<1.0 && lightmapFade>0.0) {

                vec3 sky = getSkyref(vec.view, scene.normal, 4);

                reflectCol  = mix(sky*lightmapFade*roughnessFade, reflectCol, reflectAlpha);
                reflectAlpha = max(1.0*lightmapFade*roughnessFade, reflectAlpha);
            }
            #endif

            if(metals >= 50 && metals <= 220) {
                mat2x3 metalNK = getMetalIOR(metals);
                metalFresnel = getComplexFresnel(metalNK[0], metalNK[1]);
                returnCol   *= 1.0-vec3avg(sqr(metalFresnel))*(reflectAlpha*0.9+0.1)*roughnessFade;
                reflectCol  *= sqr(metalFresnel)*reflectAlpha;
            } else if (metals > 220) {
                fresnel      = sqr(linStep(baseFresnel, 0.0, 0.25))*0.25+0.75;
                returnCol   *= mix(1.0, 1.0-fresnel, reflectAlpha);
                returnCol   *= mix(albedoColor, vec3(0.1), reflectAlpha);

                reflectCol  *= albedoColor*fresnel*reflectAlpha;
            } else {
                returnCol   *= mix(1.0, 1.0-fresnel, reflectAlpha);
                reflectCol  *= fresnel*reflectAlpha;
                simpleFog(reflectCol, fresnel);
            }

            returnCol   += reflectCol;

            if (metals>20) simpleFog(returnCol, 1.0);
        }
    #endif

    #ifdef s_godrays
        godrays();
    #endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
}