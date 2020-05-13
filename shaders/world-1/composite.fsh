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

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

vec3 decode3x8(float a){
    int bf = int(a*65535.);
    return vec3(bf%32, (bf>>5)%64, bf>>11) / vec3(31,63,31);
}

vec3 blend_translucencies(vec3 scenecol, vec4 translucents, vec3 albedo) {
    vec3 color  = scenecol;
        color  *= mix(vec3(1.0), albedo, translucents.a);
        color   = mix(color, translucents.rgb, translucents.a);

    return color;
}

void main() {
    vec4 scenecol   = stex(colortex0);  //that macro certainly makes it neater
    //vec4 tex1       = stex(colortex1);
    vec4 tex2       = stex(colortex2);
    vec4 tex3       = stex(colortex3);

    vec3 translucent_albedo = pow2(decode3x8(tex2.g));

    scenecol.rgb    = blend_translucencies(scenecol.rgb, tex3, translucent_albedo);

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
}