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

#define sunlight_luma 1.0
#define skylight_luma 1.0
#define blocklight_luma 1.0

flat out mat3x3 light_color;

void make_colors() {
    light_color[0]  = vec3(0.5, 0.3, 1.0);
    light_color[0] *= sunlight_luma*0.1;

    light_color[1]  = vec3(0.4, 0.2, 1.0);
    light_color[1] *= skylight_luma*0.3;

    light_color[2]  = vec3(1.0, 0.28, 0.0)*blocklight_luma;
}