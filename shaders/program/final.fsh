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

in vec2 coord;

uniform sampler2D colortex0;

uniform vec2 pixelSize;
uniform vec2 viewSize;

float bayer2  (vec2 c) { c = 0.5 * floor(c); return fract(1.5 * fract(c.y) + c.x); }
float bayer4  (vec2 c) { return 0.25 * bayer2 (0.5 * c) + bayer2(c); }
float bayer8  (vec2 c) { return 0.25 * bayer4 (0.5 * c) + bayer2(c); }
float bayer16 (vec2 c) { return 0.25 * bayer8 (0.5 * c) + bayer2(c); }

#define screenBitdepth 8   //[1 2 4 6 8]

vec3 dither_image(vec3 color) {
    const uint bits = uint(pow(2, screenBitdepth));

    vec3 c_dither   = color;
        c_dither   *= bits;
        c_dither   += bayer16(gl_FragCoord.xy);

    return round(c_dither)/bits;
}

#include "/lib/util/bicubic.glsl"
/*
vec4 texture_sharp(sampler2D tex, vec2 uv, const float w) {
    vec2 res    = textureSize(tex, 0);

    vec2 pixelSize = rcp(res);

    float weight = 0.0;

    float corner_weight         = -0.5*w;
    float edge_weight           = 0.46*w;
    const float center_weight   = 1.4;

    vec4 tl     = texture(tex, uv + vec2( 1.0,  1.0)*pixelSize)*corner_weight;    weight += corner_weight;
    vec4 tc     = texture(tex, uv + vec2( 0.0,  1.0)*pixelSize)*edge_weight;    weight += edge_weight;
    vec4 tr     = texture(tex, uv + vec2(-1.0,  1.0)*pixelSize)*corner_weight;    weight += corner_weight;

    vec4 ml     = texture(tex, uv + vec2( 1.0,  0.0)*pixelSize)*edge_weight;    weight += edge_weight;
    vec4 mc     = texture(tex, uv)                  *center_weight;    weight += center_weight;
    vec4 mr     = texture(tex, uv + vec2(-1.0,  0.0)*pixelSize)*edge_weight;    weight += edge_weight;

    vec4 bl     = texture(tex, uv + vec2( 1.0, -1.0)*pixelSize)*corner_weight;    weight += corner_weight;
    vec4 bc     = texture(tex, uv + vec2( 0.0, -1.0)*pixelSize)*edge_weight;    weight += edge_weight;
    vec4 br     = texture(tex, uv + vec2(-1.0, -1.0)*pixelSize)*corner_weight;    weight += corner_weight;

    float norm  = 1.0/weight;

    vec4 col    = (tl+tc+tr+ml+mc+mr+bl+bc+br)*norm;

    if (col.x < 0.0 || col.y < 0.0 || col.z < 0.0) col = mc;

    return col;
}*/

vec3 texture_cas(sampler2D tex, vec2 uv, const float w) {   //~8fps
    vec2 res    = textureSize(tex, 0);
    vec2 pixelSize = rcp(res);

    vec3 tl     = texture(tex, uv + vec2( 1.0,  1.0)*pixelSize).rgb;
    vec3 tc     = texture(tex, uv + vec2( 0.0,  1.0)*pixelSize).rgb;
    vec3 tr     = texture(tex, uv + vec2(-1.0,  1.0)*pixelSize).rgb;

    vec3 ml     = texture(tex, uv + vec2( 1.0,  0.0)*pixelSize).rgb;
    vec3 mc     = texture(tex, uv).rgb;
    vec3 mr     = texture(tex, uv + vec2(-1.0,  0.0)*pixelSize).rgb;

    vec3 bl     = texture(tex, uv + vec2( 1.0, -1.0)*pixelSize).rgb;
    vec3 bc     = texture(tex, uv + vec2( 0.0, -1.0)*pixelSize).rgb;
    vec3 br     = texture(tex, uv + vec2(-1.0, -1.0)*pixelSize).rgb;

    vec3 avg    = (tl + tc + tr + ml + mc + mr + bl + bc + br) * rcp(9.0);

    vec3 delta  = abs(tl - avg) + abs(tc - avg) + abs(tr - avg) + 
                abs(ml - avg) + abs(mc - avg) + abs(mr - avg) +
                abs(bl - avg) + abs(bc - avg) + abs(br - avg);
    
    float contrast  = 1.0 - getLuma(delta) * rcp(9.0);

    vec3 color  = mc * (1.0 + w * contrast);
        color  -= (tc + bc + ml + mr + (tl + tr + bl + br) * rcp(2.0)) * rcp(6.0) * w * contrast;

    if (color.x < 0.0 || color.y < 0.0 || color.z < 0.0) color = mc;

    return max(color, 0.0);
}

void main() {
    vec3 scene_sdr  = vec3(0.0);
    
    #ifdef image_sharpen
        if (MC_RENDER_QUALITY > 0.9) {
            scene_sdr  = texture_cas(colortex0, coord, 0.1).rgb;
        } else if (MC_RENDER_QUALITY < 0.6) {
            scene_sdr = texture_cas(colortex0, coord, 0.6).rgb;
        } else {
            scene_sdr = texture_cas(colortex0, coord, 0.4).rgb;
        }
    #else
        if (MC_RENDER_QUALITY > 0.9) {
            scene_sdr  = stex(colortex0).rgb;
        } else {
            scene_sdr  = textureBicubic(colortex0, coord).rgb;
        }
    #endif

    scene_sdr   = dither_image(scene_sdr);

    gl_FragColor = vec4(scene_sdr, 1.0);
}