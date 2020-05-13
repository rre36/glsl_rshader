#version 400 compatibility

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

in mat2x2 coord;

in vec4 tint;

flat in int mat_id;

flat in vec3 normal;

flat in mat2x3 light_color;

uniform sampler2D gcolor;

uniform vec3 lightvec, lightvecView;

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

vec3 get_lblock(vec3 lcol, float lmap) {
    return pow5(lmap)*lcol;
}

vec3 get_light(vec3 scenecol, vec3 normal, vec2 lmap, float ao) {
    float shadow    = 1.0;
    vec3 shadowcol  = vec3(1.0);
    lmap.y          = pow3(lmap.y);
    ao              = pow2(ao);

    vec3 indirect_light = light_color[0];
        indirect_light += vec3(0.5, 0.7, 1.0)*0.01*minlight_luma;
        indirect_light *= ao;

    vec3 result     = indirect_light;
        result     += get_lblock(light_color[1], lmap.x)*ao;

    return scenecol * result;
}

void main() {
    vec4 scenecol   = texture(gcolor, coord[0]);
    if (scenecol.a<0.02) discard;
        scenecol.rgb *= tint.rgb;

    scenecol.rgb    = to_linear(scenecol.rgb);

    vec3 hue    = normalize(scenecol.rgb);

    scenecol.rgb = get_light(scenecol.rgb, normal, coord[1], tint.a);

    /*DRAWBUFFERS:312*/
    gl_FragData[0]  = makeDrawbuffer(scenecol.rgb, saturate(scenecol.a));
    gl_FragData[1]  = vec4(encodeNormal(normal), encode2x8(coord[1]), 1.0);
    gl_FragData[2]  = vec4(encodeMatID16(mat_id), encode3x8(hue), 0.0, 1.0);
}