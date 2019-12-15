#version 400 compatibility
#include "/lib/util/math.glsl"
uniform sampler2D colortex0;
in vec2 coord;

#include "/lib/util/colorConversion.glsl"

void main() {
    vec4 inputSample    = texture(colortex0, coord);
    vec3 albedo         = toLinear(inputSample.rgb);

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = toVec4(max(albedo, 0.0));
}