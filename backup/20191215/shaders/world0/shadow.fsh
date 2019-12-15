#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/colorConversion.glsl"

uniform sampler2D tex;

in vec4 col;
in vec2 coord;

vec3 returnCol;
float returnAlpha;

uniform int blockEntityId;

void main() {
    vec4 fragSample     = texture(tex, coord, -1);
        returnCol       = toLinear(fragSample.rgb*col.rgb);

        returnAlpha     = fragSample.a;

    if (blockEntityId == 138) discard;

    gl_FragColor = vec4(returnCol, returnAlpha);
}