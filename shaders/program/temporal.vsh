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

out vec2 coord;

flat out float exposure;

const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex4;

uniform sampler2D depthtex1;

uniform float frameTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float nightVision;

uniform vec2 pixelSize, viewSize;

float get_imageLuma(sampler2D tex) {
    vec3 sample1    = textureLod(tex, vec2(0.5), ceil(log2(max(viewHeight, viewWidth))*1.5)).rgb;
    //vec3 sample2    = textureLod(tex, vec2(0.5), ceil(log2(max(viewHeight, viewWidth)))*rcp(1.5)).rgb;

    return getLumaPerceptual(sample1);
}

float temporal_exp() {
    float exp_curr  = clamp(texture(colortex4, vec2(0.5)).a, 0.0, 65535.0);
    float exp_targ  = rcp(get_imageLuma(colortex0));
        exp_targ    = clamp(exp_targ, 2.0, 50.0 * rcp(exposure_minlum) + nightVision*15.0);
        exp_targ    = log2(exp_targ * rcp(6.0));    //adjust this
        exp_targ    = 1.2 * pow(2.0, exp_targ);

    return mix(exp_curr, exp_targ, 0.035 * exposure_speed * (frameTime * crcp(0.033)));
}

void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
    coord = gl_MultiTexCoord0.xy;

    exposure  = temporal_exp();
}