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

uniform float wetness;

uniform vec3 sunvec;
uniform vec3 moonvec;

uniform vec4 daytime;

flat out float light_flip;

flat out mat2x3 sky_color;
flat out mat4x3 lightColor;

void make_colors() {
    vec3 sunlightSunrise;
        sunlightSunrise.r   = 1.0;
        sunlightSunrise.g   = 0.48;
        sunlightSunrise.b   = 0.0;
        sunlightSunrise    *= 0.8;

    vec3 sunlightNoon;
        sunlightNoon.r      = 1.0;
        sunlightNoon.g      = 1.0;
        sunlightNoon.b      = 1.0;
        sunlightNoon       *= 1.2;

    vec3 sunlightSunset;
        sunlightSunset.r    = 1.0;
        sunlightSunset.g    = 0.4;
        sunlightSunset.b    = 0.0;
        sunlightSunset     *= 0.6;

    vec3 sunlightNight;
        sunlightNight.r     = 1.0;
        sunlightNight.g     = 0.2;
        sunlightNight.b     = 0.0;
        sunlightNight      *= 0.5;

    lightColor[0]  = sunlightSunrise*daytime.x + sunlightNoon*daytime.y + sunlightSunset*daytime.z + sunlightNight*daytime.w;
    lightColor[0] *= pi * sunlight_luma;

    vec3 skylightSunrise;
        skylightSunrise.r   = 1.0;
        skylightSunrise.g   = 0.7;
        skylightSunrise.b   = 0.3;
        skylightSunrise    *= 0.6;

    vec3 skylightNoon;
        skylightNoon.r      = 1.0;
        skylightNoon.g      = 1.0;
        skylightNoon.b      = 1.0;
        skylightNoon       *= 1.0;

    vec3 skylightSunset;
        skylightSunset.r    = 1.0;
        skylightSunset.g    = 0.6;
        skylightSunset.b    = 0.2;
        skylightSunset     *= 0.5;

    vec3 skylightNight;
        skylightNight.r     = 0.0;
        skylightNight.g     = 0.7;
        skylightNight.b     = 1.0;
        skylightNight      *= 0.03;

    lightColor[1]  = skylightSunrise*daytime.x + skylightNoon*daytime.y + skylightSunset*daytime.z + skylightNight*daytime.w;
    lightColor[1] *= skylight_luma*0.5;
    lightColor[2]  = vec3(1.0, 0.22, 0.03)*blocklight_luma;
    lightColor[3]  = vec3(0.4, 0.7, 1.0)*0.05;

    float lf    = dot(sunvec, vec3(0.0, 1.0, 0.0))*0.5+0.5;
        lf      = linStep(lf, 0.48, 0.499)*(1.0-linStep(lf, 0.501, 0.52));

    light_flip  = saturate(1.0-lf);

    #ifdef skypass
        vec3 skySunrise;
            skySunrise.r = 0.15;
            skySunrise.g = 0.46;
            skySunrise.b = 1.00;
            skySunrise  *= 0.4;

        vec3 skyNoon;
            skyNoon.r   = 0.0;
            skyNoon.g   = 0.53;
            skyNoon.b   = 1.0;
            skyNoon    *= 1.0;

        vec3 skySunset;
            skySunset.r = 0.1;
            skySunset.g = 0.25;
            skySunset.b = 1.0;
            skySunset  *= 0.48;

        vec3 skyNight;
            skyNight.r  = 0.0;
            skyNight.g  = 0.35;
            skyNight.b  = 1.0;
            skyNight   *= 0.01;

        sky_color[0]    = skySunrise*daytime.x + skyNoon*daytime.y + skySunset*daytime.z + skyNight*daytime.w;

        vec3 horSunrise;
            horSunrise.r = 1.0;
            horSunrise.g = 0.28;
            horSunrise.b = 0.44;
            horSunrise  *= 0.9;

        vec3 horNoon;
            horNoon.r   = 0.37;
            horNoon.g   = 0.71;
            horNoon.b   = 1.00;
            horNoon    *= 1.4;

        vec3 horSunset;
            horSunset.r = 1.00;
            horSunset.g = 0.42;
            horSunset.b = 0.90;
            horSunset  *= 0.95;

        vec3 horNight;
            horNight.r  = 0.08;
            horNight.g  = 0.50;
            horNight.b  = 1.00;
            horNight   *= 0.04;

        sky_color[1]    = horSunrise*daytime.x + horNoon*daytime.y + horSunset*daytime.z + horNight*daytime.w;
    #endif
}