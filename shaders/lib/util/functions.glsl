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



float rcp(float x) {
    return crcp(x);
}
vec2 rcp(vec2 x) {
    return crcp(x);
}
vec3 rcp(vec3 x) {
    return crcp(x);
}

float pow2(float x) {
    return x*x;
}
float pow3(float x) {
    return pow2(x)*x;
}
float pow4(float x) {
    return pow2(x)*pow2(x);
}
float pow5(float x) {
    return pow4(x)*x;
}
float pow6(float x) {
    return pow5(x)*x;
}
float pow8(float x) {
    return pow4(x)*pow4(x);
}

vec2 pow2(vec2 x) {
    return x*x;
}

vec3 pow2(vec3 x) {
    return x*x;
}

vec4 pow2(vec4 x) {
    return x*x;
}

float cubeSmooth(in float x) {
    return icubeSmooth(x);
}
float v3avg(vec3 x) {
    return (x.x+x.y+x.z)/3.0;
}

float flength(vec2 x) {
    return sqrt(dot(x, x));
}
float flength(vec3 x) {
    return sqrt(dot(x, x));
}

float max3(float x, float y, float z) {
    return max(x, max(y, z));
}

float max3(vec3 x) {
    return max(x.x, max(x.y, x.z));
}

float min3(float x, float y, float z) {
    return min(x, min(y, z));
}

float min3(vec3 x) {
    return min(x.x, min(x.y, x.z));
}

vec3 greaterThanVec3(vec3 x, vec3 y, vec3 a, vec3 b) {
    vec3 data   = vec3(0.0);
        data.x  = x.x > y.x ? a.x : b.x;
        data.y  = x.y > y.y ? a.y : b.y;
        data.z  = x.z > y.z ? a.z : b.z;

    return data;
}
vec3 smallerThanVec3(vec3 x, vec3 y, vec3 a, vec3 b) {
    vec3 data   = vec3(0.0);
        data.x  = x.x < y.x ? a.x : b.x;
        data.y  = x.y < y.y ? a.y : b.y;
        data.z  = x.z < y.z ? a.z : b.z;

    return data;
}

float saturate(in float x) {
    return csaturate(x);
}

vec2 saturate(in vec2 x) {
    return csaturate(x);
}

vec3 saturate(in vec3 x) {
    return csaturate(x);
}

float linStep(float x, float low, float high) {
    float t = saturate((x-low)/(high-low));
    return t;
}

vec3 linStep(vec3 x, float low, float high) {
    vec3 t = saturate((x-low)/(high-low));
    return t;
}

float getLuma(vec3 x) {
    return dot(x, lumacoeff_rec709);
}
float getLumaPerceptual(vec3 x) {
    return dot(x, lumacoeff_relative);
}

vec3 colorSaturation(vec3 x, const float y) {
    return mix(vec3(getLuma(x)), x, y);
}

vec4 makeDrawbuffer(in vec3 scenecol, in float alpha) {
    #ifdef MC_GL_RENDERER_GEFORCE
        vec3 temp   = clamp(scenecol, 1.0/65530.0, 65535.0);   //NaN fix on nvidia
    #else
        vec3 temp   = clamp(scenecol, 0.0, 65535.0);
    #endif

    return vec4(temp, alpha);
}
vec4 makeDrawbuffer(in vec3 scenecol) {
    #ifdef MC_GL_RENDERER_GEFORCE
        vec3 temp   = clamp(scenecol, 1.0/65530.0, 65535.0);   //NaN fix on nvidia
    #else
        vec3 temp   = clamp(scenecol, 0.0, 65535.0);
    #endif

    return vec4(temp, 1.0);
}
vec4 makeDrawbuffer(in vec4 scenecol) {
    #ifdef MC_GL_RENDERER_GEFORCE
        vec3 temp   = clamp(scenecol.rgb, 1.0/65530.0, 65535.0);
    #else
        vec3 temp   = clamp(scenecol.rgb, 0.0, 65535.0);
    #endif

    return vec4(temp, max(scenecol.a, 0.0));
}

//these are for non-scenecolor stuffs
vec4 clampDrawbuffer(in vec3 scenecol) {
    vec3 temp   = clamp(scenecol, 0.0, 65535.0);

    return vec4(temp, 1.0);
}
vec4 clampDrawbuffer(in vec4 scenecol) {
    vec3 temp   = clamp(scenecol.rgb, 0.0, 65535.0);

    return vec4(temp, max(scenecol.a, 0.0));
}