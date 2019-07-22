#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

out vec4 col;
out vec2 coord;
out vec2 lmap;
flat out vec3 nrm;
flat out int water;

attribute vec4 mc_Entity;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 upPosition;

flat out vec3 upVector;

#include "/lib/util/taaJitter.glsl"

#include "/lib/end/nvars.glsl"

void main() {
    nature();

    gl_Position     = ftransform();

    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) water = 1;
    else water = 0;

    #ifdef temporalAA
        gl_Position.xy  = taaJitter(gl_Position.xy, gl_Position.w);
    #endif

    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
    upVector        = normalize(upPosition);
}