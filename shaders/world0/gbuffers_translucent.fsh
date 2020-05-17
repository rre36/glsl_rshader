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
#include "/lib/util/encoders.glsl"

const int shadowMapResolution   = 2560;     //[512 1024 1536 2048 4560 3072 3584 4096 6144 8192 16384]

in mat2x2 coord;

in float warp;

in vec3 pos_shadow;
in vec3 world_pos;

in vec4 tint;

flat in int mat_id;

flat in vec3 normal;

flat in float light_flip;

flat in mat4x3 lightColor;

uniform sampler2D gcolor;

uniform sampler2D noisetex;

uniform int frameCounter;

uniform float sunAngle;

uniform vec3 lightvec, lightvecView;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

float encodeMatID16(int x) {
    float id    = float(x)/65535.0;
    return id;
}

float bayer2e(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}
#define bayer4e(a)   (bayer2e( .5*(a))*.25+bayer2e(a))

#define m vec3(31,63,31)
float encode3x8(vec3 a){
    float dither = bayer4e(gl_FragCoord.xy);
    a += (dither-.5) / m;
    a = saturate(a);
    ivec3 b = ivec3(a*m);
    return float( b.r|(b.g<<5)|(b.b<<11) ) / 65535.;
}
#undef m

#include "/lib/light/diffuse.glsl"

float get_specGGX(vec3 normal, vec3 viewvec, vec3 lvec, float roughness) {
    const float f0  = 0.02;
    roughness  *= roughness;

    vec3 h      = lvec - viewvec;
    float hn    = inversesqrt(dot(h, h));
    float hDotL = saturate(dot(h, lvec)*hn);
    float hDotN = saturate(dot(h, normal)*hn);
    float nDotL = saturate(dot(normal, lvec));
    float denom = (hDotN * roughness - hDotN) * hDotN + 1.0;
    float D     = roughness / (pi * denom * denom);
    float F     = f0 + (1.0-f0) * exp2((-5.55473*hDotL-6.98316)*hDotL);
    float k2    = 0.25 * roughness;

    return nDotL * D * F / (hDotL * hDotL * (1.0-k2) + k2);
}

float ditherBluenoise() {
    ivec2 coord = ivec2(fract(gl_FragCoord.xy/256.0)*256.0);
    float noise = texelFetch(noisetex, coord, 0).a;
        noise   = fract(noise+float(frameCounter)/4.0);

    return noise;
}

#include "/lib/light/shadow.glsl"

vec3 get_lblock(vec3 lcol, float lmap) {
    return pow5(lmap)*lcol;
}

vec3 get_light(vec3 scenecol, vec3 normal, vec2 lmap, float ao) {
    float shadow    = 1.0;
    vec3 shadowcol  = vec3(1.0);
    lmap.y          = pow3(lmap.y);

    float diff      = get_diffLambert(normal);

    get_ldirect(shadow, shadowcol, diff>0.0);

    float diff_lit  = min(diff, shadow);
    vec3 direct_col     = sunAngle<0.5 ? lightColor[0] : lightColor[3];
    vec3 direct_light   = diff_lit*shadowcol*direct_col*light_flip;
    vec3 indirect_light = lmap.y*lightColor[1];
        indirect_light += vec3(0.5, 0.7, 1.0)*0.01*minlight_luma;
        indirect_light *= ao;

    vec3 result     = direct_light + indirect_light;
        result     += get_lblock(lightColor[2], lmap.x)*ao;

    return scenecol * result;
}

void main() {
    vec4 scenecol   = texture(gcolor, coord[0]);
    if (scenecol.a<0.02) discard;
        scenecol.rgb *= tint.rgb;

    scenecol.rgb    = to_linear(scenecol.rgb);

    vec3 hue    = normalize(scenecol.rgb);

    #ifdef g_terrain
        if (mat_id == 102) {
            scenecol.rgb = vec3(0.04, 0.2, 1.0) * 0.1;
            scenecol.a = 0.7;
            hue      = vec3(1.0);
        }
    #endif

    scenecol.rgb = get_light(scenecol.rgb, normal, coord[1], tint.a);


    scenecol.rgb *= 1.0 + (1.0-scenecol.a);

    /*DRAWBUFFERS:312*/
    gl_FragData[0]  = makeDrawbuffer(scenecol.rgb, saturate(scenecol.a));
    gl_FragData[1]  = vec4(encodeNormal(normal), encode2x8(coord[1]), 1.0);
    gl_FragData[2]  = vec4(encodeMatID16(mat_id), encode3x8(hue), 0.0, 1.0);
}