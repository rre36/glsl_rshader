#version 400 compatibility
#include "/lib/util/math.glsl"

in vec2 coord;

uniform sampler2D tex;

vec4 sampleCol = vec4(0.0);

void main() {
    sampleCol = texture(tex, coord);
    sampleCol = max(sampleCol, vec4(0.0));

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = vec4(sampleCol.rgb*2.0, saturate(length(sampleCol.rgb)));
}