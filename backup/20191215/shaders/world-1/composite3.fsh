#version 400 compatibility
#define DIM -1
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

const float bloomIntensity  = 0.12;

uniform sampler2D colortex0;    //scene color
uniform sampler2D colortex4;

uniform float viewHeight;
uniform float viewWidth;

in vec2 coord;

vec3 returnCol;

#include "/lib/post/bloom2.glsl"

void main() {
    returnCol   = texture(colortex0, coord).rgb;

#ifdef setBloom
    bloom();
#endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = toVec4(returnCol);
}