/*
====================================================================================================

    Copyright (C) 2020 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.github.io/license/

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/

#include "/lib/common.glsl"

out vec2 coord;

#ifndef dim
#include "/lib/atmos/colors.glsl"
#elif dim == -1
#include "/lib/atmos/colors_n.glsl"
#elif dim == 1
#include "/lib/atmos/colors_e.glsl"
#endif

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    coord = gl_MultiTexCoord0.xy;

    make_colors();
}