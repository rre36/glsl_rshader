#version 400 compatibility

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

in vec2 coord;

in vec4 tint;

flat in int mat_id;

uniform sampler2D gcolor;

uniform int blockEntityId;

void main() {
    if (blockEntityId == 10201) discard;
    vec4 scenecol   = texture(gcolor, coord);
    if (scenecol.a<0.1) discard;
        scenecol.rgb *= tint.rgb;

    if (mat_id == 102) {
        scenecol    = vec4(1.0, 1.0, 1.0, 0.1);
    }

    gl_FragData[0]  = scenecol;
}