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


uniform float frameTimeCounter;

uniform sampler2D noisetex;

float wind_tick     = frameTimeCounter*pi;

float value_3d(vec3 pos) {
    vec3 p  = floor(pos); 
    vec3 b  = fract(pos);

    vec2 uv = (p.xy+vec2(-97.0)*p.z)+b.xy;
    vec2 rg = texture(noisetex, (uv)/256.0).xy;

    return cubeSmooth(mix(rg.x, rg.y, b.z))*2.0-1.0;
}

vec2 rotate_coord(vec2 pos, const float angle) {
    return vec2(cos(angle)*pos.x + sin(angle)*pos.y, 
                cos(angle)*pos.y - sin(angle)*pos.x);
}

float wind_macrogust(vec3 pos, const float speed) {
    float p     = pos.x + pos.z + pos.y*0.2;
    float t     = wind_tick * speed;

    float s1    = sin(t + p) * 0.7 + 0.2;
    float c1    = cos(t * 0.655 + p)*0.7+0.2;

    return s1+c1;
}
float wind_wave(vec3 pos, const float speed) {
    float p     = (pos.x + pos.z) * 0.5;
    float t     = wind_tick * speed;

    float s1    = sin(t + p) * 0.68 + 0.2;

    return s1;
}

vec2 wind_effect(vec3 pos, const float amp, const float size) {
    vec3 p      = pos * size;
        p.xz    = rotate_coord(p.xz, pi*rcp(3.0));

    vec2 macro_w = vec2(0.0);
        macro_w += wind_macrogust(p, 1.0) * vec2(1.0, 0.1);
        macro_w += wind_wave(p, 1.2)*vec2(1.0, -0.1);

    vec2 micro_w = vec2(0.0);
        micro_w += value_3d(p * 2.8 + vec3(1.0, 0.5, 0.8)*wind_tick * 0.6)*vec2(1.0, 0.7);
        micro_w -= value_3d(p * 3.9 + vec3(0.7, 0.7, 1.0)*wind_tick * 0.52)*vec2(1.0, -0.5);
        micro_w += value_3d(p * 4.3 + vec3(1.0, 0.8, 0.9)*wind_tick * 0.45)*vec2(1.0, 0.8);
        micro_w.x += 0.2;
        micro_w *= max(wind_wave(p*0.05, 0.1) + 0.6, 0.0)*0.5+0.2;

    return (macro_w*0.33 + micro_w*1.1) * vec2(-1.0, 1.0) * 0.75 * amp * wind_intensity;
}