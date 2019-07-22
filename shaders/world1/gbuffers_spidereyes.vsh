#version 400 compatibility
#include "/lib/global.glsl"

out vec2 coord;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

#include "/lib/util/taaJitter.glsl"

void main() {
    gl_Position     = ftransform();

    #ifdef temporalAA
        gl_Position.xy  = taaJitter(gl_Position.xy, gl_Position.w);
    #endif
    
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
}