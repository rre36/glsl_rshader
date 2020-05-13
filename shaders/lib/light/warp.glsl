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

#define shadowmap_bias 0.85      //this is not supposed to be a setting, but just an internal constant

float get_warp(in vec2 x) {
    return length(x * 1.169) * shadowmap_bias + (1.0 - shadowmap_bias);
}

vec2 warp_shadowmap(vec2 coord, out float distortion) {
    distortion = get_warp(coord);
    return coord/distortion;
}
vec2 warp_shadowmap(vec2 coord) {
    float distortion = get_warp(coord);
    return coord/distortion;
}