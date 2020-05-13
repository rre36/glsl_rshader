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
#include "/lib/util/srgb.glsl"
#include "/lib/util/encoders.glsl"

in mat2x2 coord;
in vec4 tint;

uniform sampler2D gcolor;

void main() {
    vec4 scenecol   = texture(gcolor, coord[0]);
        scenecol   *= tint;

    if (scenecol.a < 0.01) discard;

        scenecol.rgb = to_linear(scenecol.rgb);

    #ifdef g_spidereyes
        scenecol.rgb *= pi;
    #endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeDrawbuffer(scenecol.rgb, saturate(scenecol.a));
}