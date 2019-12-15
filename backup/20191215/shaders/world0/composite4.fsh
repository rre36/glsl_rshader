#version 400 compatibility
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

#ifdef setBloom
const bool colortex0MipmapEnabled = true;
#endif

float bloomThreshold    = 10.0;

uniform sampler2D colortex0;    //scene color
uniform sampler2D colortex3;    //scene material masks
uniform sampler2D depthtex1;

uniform int frameCounter;

uniform float viewHeight;
uniform float viewWidth;
uniform float aspectRatio;
uniform float frameTime;
uniform float rainStrength;
uniform float wetness;

in vec2 coord;

float pxWidth       = 1.0/viewWidth;

float depth;

struct maskData {
    float terrain;
    float hand;
    float translucency;
} mask;

float unmap(in float x, float low, float high) {
    if (x < low || x > high) x = low;
    x -= low;
    x /= high-low;
    x /= 0.99;
    x = clamp(x, 0.0, 1.0);
    return x;
}

void decodeBuffer() {
    vec4 maskBuffer = texture(colortex3, coord);
    float maskData  = maskBuffer.r;
    
    float matData   = maskBuffer.g;

    float beacon    = unmap(matData, 2.6, 3.5);
    
    mask.terrain    = float(maskData > 0.125 || beacon>0.5);
    mask.hand       = float(maskData > 0.375 && maskData < 0.75);
}

vec3 returnCol;

#include "/lib/post/bloom1.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/post/motionblur.glsl"

void main() {
	bloomThreshold *= 1.0-wetness*0.8;

    returnCol = textureLod(colortex0, coord, 0).rgb;

    depth   = texture(depthtex1, coord).r;

    decodeBuffer();

    vec3 blur = vec3(0.0);

#ifdef setBloom
	makeBloomBuffer(blur);
#endif

#ifdef setMotionblur
	motionblur();
#endif

    /*DRAWBUFFERS:04*/
    gl_FragData[0]  = toVec4(returnCol);
    gl_FragData[1]  = toVec4(blur);
}