#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float minLight            = 0.01;
const vec3 minLightColor        = vec3(0.8, 0.9, 1.0);
const float lightLuma           = 1.0;
const vec3 lightColor           = vec3(1.0, 0.42, 0.0);


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

#include "diffGGX.glsl"

#include "core.glsl"

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
    float lightmap      = sstep(scene.lightmap.y, 0.15, 0.95);
    float cave          = 1.0-sstep(scene.lightmap.y, 0.2, 0.5);

    vec3 indirectLight  = mix(light.sky*lightmap, light.sun, saturate(s_shadowLuminance));
        indirectLight   = mix(indirectLight, minLightColor*minLight, cave);

        indirectLight  += light.sun*sdata.indirect*(1.0-sdata.lit);

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = indirectLight+light.sun*sdata.shadowcolor*sdata.lit*finv(timeLightTransition);
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
    sdata.vanillaAo     = flatten(pow2(sample4), 0.95);

    returnCol           = scene.albedo;

    if(mask.terrain) {
        light.sun       = colSunlight*sunlightLuma;
        light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
        light.sky       = colSkylight*skylightLuma;
        light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
        light.artificial = lightColor*lightLuma;


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

        sdata.ao    *= sdata.vanillaAo;

        applyShading();
    }

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
    gl_FragData[1]  = vec4(scene.sample3.r, encodeV3(scene.albedo), scene.sample3.b, 1.0);
}