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

#define nskylight_luma 0.01
#define blocklight_luma 1.0

uniform vec3 sunvec;

uniform vec4 daytime;

flat out float light_flip;

flat out mat2x3 light_color;

#ifdef skypass
flat out vec3 sky_color;
#endif

void make_colors() {
    light_color[0]  = vec3(1.0, 0.2, 0.1)*nskylight_luma;

    light_color[1]  = vec3(1.0, 0.28, 0.0)*blocklight_luma*2.0;


    #ifdef skypass
        sky_color    = vec3(1.0, 0.15, 0.1)*0.004;
    #endif
}