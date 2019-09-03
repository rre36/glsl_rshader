#version 400 compatibility
#define DIM 1
#include "/lib/global.glsl"
#include "/lib/end/opt.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

/* ------ uniforms ------ */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D depthtex1;

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
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} vec;

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

vec3 unpackNormal(vec3 x) {
    return x*2.0-1.0;
}

void skyGradient() {
    vec3 skyVanilla = toLinear(skyColor)*0.8;
    vec3 fogVanilla = toLinear(fogColor)*2.0;

    vec3 nFrag      = -vec.view;
    vec3 hVec       = normalize(-vec.up+nFrag);
    vec3 hVec2      = normalize(vec.up+nFrag);

    float hTop      = dot(hVec, nFrag);
    float hBottom   = dot(hVec2, nFrag);

    float horizonFade = linStep(hBottom, 0.3, 0.8);
        horizonFade = pow4(horizonFade)*0.75;

    float lowDome   = linStep(hBottom, 0.66, 0.71);
        lowDome     = pow3(lowDome);

    float horizonGrad = 1.0-max(hBottom, hTop);

    float horizon   = linStep(horizonGrad, 0.15, 0.31);
        horizon     = pow6(horizon)*0.8;

    vec3 sky        = mix(skyVanilla, fogVanilla, horizonFade);
        sky         = mix(sky, fogVanilla, horizon);
        sky         = mix(sky, fogVanilla, lowDome);
        
    returnCol       = sky;
}

float noise2D(in vec2 coord) {
    coord /= noiseTextureResolution;
    return texture2D(noisetex, coord).x;
}
void skyStars() {
    vec3 fragPos = pos.view;
    vec3 normFragpos = normalize(fragPos);
    vec3 wPos = vec3(gbufferModelViewInverse * vec4(fragPos,1.0));

    vec3 planeIntersect = wPos/(wPos.y+length(wPos.xz));
    vec2 coord = floor((planeIntersect.xz*0.4+pos.camera.xz*0.0001)*1536)/1536;
    vec2 coord2 = (planeIntersect.xz)*32;
        coord *= 1024.0;

	float NdotU = sqrt(sqrt(max(dot(normFragpos,normalize(vec.up)),0.0)));
	
    vec3 colorStar = vec3(1.0, 1.0, 0.98);

	float star = 1.0;
		star *= noise2D(coord.xy);
		star *= noise2D(coord.xy+0.1);
        star *= noise2D(coord.xy+0.23);

	star = max(star-0.825,0.0)*5.0;
    star = clamp(star, 0.0, 1.0);

    returnCol += colorStar*1.0*star;
}

void main() {
    scene.albedo    = texture(colortex0, coord).rgb;
    scene.normal    = unpackNormal(texture(colortex1, coord).rgb);
    scene.sample2   = texture(colortex2, coord);
    scene.sample3   = texture(colortex3, coord);

    decodeData();

    depth.depth     = texture(depthtex1, coord).x;
    depth.linear    = depthLin(depth.depth);

    pos.camera      = cameraPosition;
    pos.view        = getViewpos(depth.depth);
    pos.world       = toWorldpos(pos.view);

    vec.up          = upVector;
    vec.view        = normalize(pos.view);

    returnCol       = scene.albedo;

    if(!mask.terrain) {
        returnCol   = vec3(0.0);
        skyStars();
    }

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
}