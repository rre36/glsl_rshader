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
#include "/lib/util/srgb.glsl"
#include "/lib/util/encoders.glsl"

in mat2x2 coord;

in vec4 tint;

flat in int discard_frag;

flat in vec3 normal;

uniform sampler2D gcolor;

float encodeMatID16(int x) {
    float id    = float(x)/65535.0;
    return id;
}

void main() {
    #ifdef hide_terrain
        discard;
    #endif

    if (discard_frag == 1) discard;

    vec4 scenecol   = texture(gcolor, coord[0]);
        scenecol *= tint;
    if (scenecol.a<0.5) discard;
    vec3 scenenormal = normal;

        scenecol.a  = 1.0;

    #ifdef labpbr_enabled
        vec4 spectex    = vec4(0.0);
        vec2 return1_zw = vec2(encode2x8(spectex.xy), encode2x8(spectex.zw));
    #else
        const vec2 return1_zw = vec2(1.0);
    #endif

    scenecol.rgb    = to_linear(scenecol.rgb);

    int matID   = 1;

    /*DRAWBUFFERS:012*/
    gl_FragData[0]  = makeDrawbuffer(scenecol.rgb, saturate(scenecol.a));
    gl_FragData[1]  = vec4(encode2x8(encodeNormal(scenenormal)), encode2x8(coord[1]), return1_zw);
    gl_FragData[2]  = vec4(encodeMatID16(matID), 0.0, 0.0, 0.0);
}