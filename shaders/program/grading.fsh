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

#define INFO 0  //[0]

/* ------ color grading related settings ------ */
//#define do_colorgrading

#define vibrance_int 1.00       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define saturation_int 1.00     //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define gamma_curve 1.00        //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define brightness_int 0.00     //[-0.50 -0.45 -0.40 -0.35 -0.30 -0.25 -0.20 -0.15 -0.10 -0.05 0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.5]
#define constrast_int 1.00      //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

#define colorlum_r 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define colorlum_g 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define colorlum_b 1.00         //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00 1.05 1.10 1.15 1.20 1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]

//#define vignette_enabled
#define vignette_start 0.15     //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignette_end 0.85       //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignette_intensity 0.75 //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define vignette_exponent 1.50  //[0.50 0.75 1.0 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00]

in vec2 coord;

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform int frameCounter;

uniform float frameTimeCounter;
uniform float nightVision;

uniform vec2 pixelSize;
uniform vec2 viewSize;

/* ------ tonemapping operators ------ */

vec3 tonemap_reinhard(vec3 hdr) {
    hdr    *= 1.25;
    float luma      = getLuma(hdr);

    float coeff     = 0.9 - nightVision*0.7;

    vec3 col        = hdr/(hdr + coeff);
        col         = mix(hdr/(luma + coeff), col, col);

    return to_srgb(col);
}

vec3 tonemap_hejlBurgess(vec3 hdr) {
    hdr    *= 0.63;

    const float blackClip   = 0.001;
    const float A           = 6.2;  //seems to control brightness, reciprocal
    const float B           = 0.62;     //seems to adjust slope
    const float C           = 1.45;  //seems to adjust contrast
    const float D           = 0.05;

    vec3 x     = max(hdr - blackClip, 0.0);    
    return (x * (A * x + B)) * rcp(x * (A * x + C) + D);
}

/* ------ color grading utilities ------ */

vec3 rgb_luma(vec3 x) {
    return x * vec3(colorlum_r, colorlum_g, colorlum_b);
}

vec3 gammacurve(vec3 x) {
    return pow(x, vec3(gamma_curve));
}

vec3 vibrance_saturation(vec3 color) {
    const float vint    = max(vibrance_int - 0.01, 0.0);
    float lum   = dot(color, lumacoeff_rec709);
    float mn    = min(min(color.r, color.g), color.b);
    float mx    = max(max(color.r, color.g), color.b);
    float sat   = (1.0 - saturate(mx-mn)) * saturate(1.0-mx) * lum * 5.0;
    vec3 light  = vec3((mn + mx) / 2.0);

    color   = mix(color, mix(light, color, vint), saturate(sat));

    color   = mix(color, light, saturate(1.0-light) * (1.0-vint) / 2.0 * abs(vint));

    color   = mix(vec3(lum), color, saturation_int);

    return color;
}

vec3 brightness_contrast(vec3 color) {
    return (color - 0.5) * constrast_int + 0.5 + brightness_int;
}

vec3 vignette(vec3 color) {
    float fade      = length(coord*2.0-1.0);
        fade        = linStep(abs(fade) * 0.5, vignette_start, vignette_end);
        fade        = 1.0 - pow(fade, vignette_exponent) * vignette_intensity;

    return color * fade;
}

void main() {
    vec3 scene_hdr  = stex(colortex0).rgb;

    #ifdef bloom_enabled
    vec2 cres       = max(viewSize, vec2(1920.0, 1080.0));

    float bloom_int = 0.025 + max(stex(colortex4).a, 1.0)*0.0025;

    #if dim == -1
        bloom_int  *= 1.3;
    #elif dim == 1
        bloom_int  *= 1.5;
    #endif

        scene_hdr  += texture(colortex3, coord/cres*vec2(1920.0, 1080.0)*0.5).rgb*bloom_int;  //apply bloom
    #endif

    #ifdef manual_exposure_enabled
        scene_hdr  *= rcp(manual_exposure);
    #else
        scene_hdr  *= stex(colortex4).a;
    #endif

        scene_hdr   = vibrance_saturation(scene_hdr);

    #ifdef do_colorgrading
        scene_hdr   = rgb_luma(scene_hdr);
    #endif

    #ifdef vignette_enabled
        scene_hdr    = vignette(scene_hdr);
    #endif

    vec3 scene_sdr  = tonemap_hejlBurgess(scene_hdr);

    #ifdef do_colorgrading
        scene_sdr    = brightness_contrast(scene_sdr);
        scene_sdr    = gammacurve(scene_sdr);
    #endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeDrawbuffer(scene_sdr);
}