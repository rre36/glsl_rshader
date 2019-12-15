#version 400 compatibility
#define DIM -1
#include "/lib/global.glsl"
#include "/lib/nether/opt.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

const float lightLuma           = 1.0;
const vec3 lightColor           = vec3(1.0, 0.42, 0.0);

/* ------ buffer formats ------ */

const int colortex0Format   = RGB16F;
const int colortex1Format   = RGB16F;
const int colortex2Format   = RGB16;
const int colortex3Format   = RGBA16;
const int colortex4Format   = RGBA16F;
const int colortex6Format   = RGBA16;


/* ------ uniforms ------ */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform sampler2D depthtex1;

uniform int frameCounter;

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 upPosition;
uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;


/* ------ inputs from vertex stage ------ */

in vec2 coord;

flat in vec3 upVector;

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
    vec3 up;
    vec3 view;
} vec;

struct shadingData {
    float ao;
    float vanillaAo;
    vec3 result;
    float lightmap;
} sdata;

struct lightData {
    vec3 sky;
    vec3 artificial;
} light;

struct returnData {
    float ao;
} rdata;

vec3 returnCol = vec3(0.0);


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
    sdata.lightmap      = sstep(scene.lightmap.y, 0.15, 0.95);

    vec3 indirectLight  = light.sky;

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = indirectLight;
        directLight     = bLighten(directLight, artificial);

    vec3 metalCol       = scene.albedo*normalize(scene.albedo);

    returnCol          *= 1.0-pbr.metallic;

    sdata.result        = directLight*sdata.ao;
    returnCol          *= sdata.result;

    returnCol          += metalCol*pbr.metallic*sdata.result;
}


void main() {
    scene.albedo    = texture(colortex0, coord).rgb;
    scene.normal   = unpackNormal(texture(colortex1, coord).rgb);
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

    vec.up          = upVector;
    vec.view        = normalize(pos.view);

    light.sky       = colSkylight*skylightLuma;
    light.artificial = lightColor*lightLuma;

    sdata.ao            = 1.0;
    sdata.vanillaAo     = flatten(sample4, 0.85);

    returnCol           = scene.albedo;

    if(mask.terrain) {
        float worldDistance = length(pos.world.xyz-pos.camera.xyz);
        float falloff       = 1.0-pow2(linStep(worldDistance, 100.0, 160.0));

        #ifdef setAmbientOcclusion
            dbao(falloff);
        #endif
        sdata.ao *= sdata.vanillaAo;

        applyShading();
    }

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
    gl_FragData[1]  = vec4(scene.sample3.r, encodeV3(scene.albedo), scene.sample3.b, 1.0);
}