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

vec2 encodeNormal(in vec3 normal) {
    normal.xy = normal.xy / dot(abs(normal), vec3(1.0)) + 0.00390625;
    normal.xy = normal.z <= 0.0 ? (1.0 - abs(normal.yx)) * sign(normal.xy) : normal.xy;
    return normal.xy * 0.5 + 0.5;
}

vec3 decodeNormal(in vec2 encodedNormal) {
    vec3 normal = vec3(0.0);
    encodedNormal = encodedNormal * 2.0 - 1.0;
    normal.xy = abs(encodedNormal);
    normal.z = 1.0 - normal.x - normal.y;
    normal.xy = (1.0 - normal.yx) * sign(encodedNormal);
    normal.xy = normal.z <= 0.0 ? normal.xy : encodedNormal;
    return normalize(normal.xyz);
}

float encode2x8(in vec2 toEnc) {
    uvec2 bitfield = uvec2(toEnc * 255.0 + 0.5);
    return float(bitfield.x | bitfield.y << 8u) / 65535.0;
}

vec2 decode2x8(in float toDec) {
    uint bitfield = uint(toDec * 65535.0);
    return vec2(bitfield & 255u, bitfield >> 8u) / 255.0;
}