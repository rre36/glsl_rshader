#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float shadowIllumination  = 0.0;
const float sunlightLuma        = 2.5;
const float skylightLuma        = 0.1;
const float minLight            = 0.01;
const vec3 minLightColor        = vec3(0.8, 0.9, 1.0);
const float lightLuma           = 1.0;
const vec3 lightColor           = vec3(1.0, 0.42, 0.0);


/* ------ uniforms ------ */

uniform sampler2D tex;

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

#ifdef setDynamicShadows
const bool shadowHardwareFiltering = true;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

uniform sampler2DShadow shadowcolor0;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
#endif


/* ------ inputs from vertex stage ------ */

in vec4 col;
in vec2 coord;
in vec2 lmap;
flat in vec3 nrm;

flat in vec3 upVector;

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
    vec3 up;
    vec3 camera;
    vec3 screen;
    vec3 world;
} pos;

struct vectorData {
    vec3 up;
    vec3 view;
} vec;

struct shadingData {
    float ao;
    float lightmap;
    vec3 skylight;
    vec3 result;
} sdata;

struct lightData {
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

    vec3 indirectLight  = light.sky;

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = indirectLight;
        directLight     = bLighten(directLight, artificial);

    sdata.result        = directLight*sdata.ao;
    rdata.scene.rgb    *= sdata.result;
}

void main() {
vec4 inputSample        = texture(tex, coord);
    inputSample.rgb    *= col.rgb;
    scene.albedo        = toLinear(inputSample.rgb);
    scene.normal        = nrm;
    scene.lightmap      = lmap;

    depth.depth         = gl_FragCoord.z;
    depth.linear        = depthLin(depth.depth);

    pbr.roughness       = water==1 ? 0.0 : 0.25;
    pbr.specular        = 0.5;
    pbr.metallic        = 0.0;

    rdata.scene.rgb     = scene.albedo;
    rdata.lmap          = lmap;
    rdata.materials     = 0.0;
    rdata.metalness     = pbr.metallic;
    rdata.roughness     = pbr.roughness;
    rdata.specular      = pbr.specular;

    sdata.ao            = flatten(col.a, 0.85);

    sdata.result        = vec3(0.0);

    pos.up          = upPosition;
    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth);
    pos.world       = worldSpacePos(depth.depth);

    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    light.sky       = colSkylight*skylightLuma;
    light.artificial = lightColor*lightLuma;

    sdata.skylight  = light.sky;

    applyShading();

    rdata.scene.a       = water == 1 ? pow2(inputSample.a) : inputSample.a;

    /*DRAWBUFFERS:612*/
    gl_FragData[0] = makeSceneOutput(rdata.scene)*vec4(vec3(0.1), 1.0);
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(rdata.lmap, encodeV2(rdata.specular, rdata.roughness), 1.0);
    //gl_FragData[3] = vec4(0.25, rdata.materials, 0.0, 1.0);
    //gl_FragData[4] = vec4(vec3(0.0), col.a);
}