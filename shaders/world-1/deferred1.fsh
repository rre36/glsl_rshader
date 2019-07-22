#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/nether/opt.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"


/* ------ buffer formats ------ */

const int colortex0Format   = R11F_G11F_B10F;
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
    float vanillaAo;
} sdata;

struct returnData {
    float ao;
} rdata;


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

    pos.up          = upPosition;
    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth);
    pos.world       = worldSpacePos(depth.depth);

    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    sdata.ao            = 1.0;
    sdata.vanillaAo     = flatten(sample4, 0.85);

    if(mask.terrain) {
        float worldDistance = length(pos.world.xyz-pos.camera.xyz);
        float falloff       = 1.0-pow2(linStep(worldDistance, 100.0, 160.0));

        #ifdef setAmbientOcclusion
            dbao(falloff);
        #endif
    }

    rdata.ao            = sdata.ao*sdata.vanillaAo;

    /*DRAWBUFFERS:4*/
    gl_FragData[0]  = vec4(vec3(0.0), rdata.ao);
}