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


#ifdef g_solid
vec3 get_shadowcoord(vec3 viewpos, const float bias, out float warp) {  //shadow 2d
    vec3 pos    = viewpos;
        pos     = viewMAD(gbufferModelViewInverse, pos);
        pos    += vec3(bias)*lightvec;
    float a    = length(pos);
        pos     = viewMAD(shadowModelView, pos);
        pos     = projMAD(shadowProjection, pos);
        pos.z  *= 0.2;
        pos.z  -= 0.0012*(saturate(a/256.0));

        warp    = 1.0;
        pos.xy  = warp_shadowmap(pos.xy, warp);

    return pos*0.5+0.5;
}
#endif

float get_softshadow(sampler2DShadow tex, vec3 pos) {
    float step  = rcp(float(shadowMapResolution));
    float n     = ditherBluenoise()*pi;
    vec2 noise  = vec2(cos(n), sin(n));
    vec3 offset = vec3(noise, 0.0)*step;

    float s0    = shadow2D(tex, pos).x*0.5;
    float s1    = shadow2D(tex, pos+offset).x;
    float s2    = shadow2D(tex, pos-offset).x;

    return saturate((s0 + s1 + s2)*0.4);
}

float get_softshadow_hq(sampler2DShadow tex, vec3 pos) {
    float step  = rcp(float(shadowMapResolution));
    float n     = ditherBluenoise()*pi;
    vec2 noise  = vec2(cos(n), sin(n));
    vec3 offset = vec3(noise, 0.0)*step;

    float s0    = shadow2D(tex, pos).x;
    float s1    = shadow2D(tex, pos+offset).x;
    float s2    = shadow2D(tex, pos-offset).x;
    float s3    = shadow2D(tex, pos+offset*2.0).x*0.5;
    float s4    = shadow2D(tex, pos-offset*2.0).x*0.5;

    return (s0 + s1 + s2 + s3 + s4)/4.0;
}

vec3 get_shadowcol(sampler2D tex, vec2 coord) {
    vec4 x  = texture(tex, coord);
    return mix(vec3(1.0), x.rgb, x.a);
}

#ifdef g_solid
void get_ldirect(out float shadow, out vec3 shadowcol, bool diffLit, vec3 viewpos) {
    const float bias    = 0.08*(2048.0/shadowMapResolution);
    float warp          = 1.0;
    shadow              = 1.0;
    shadowcol           = vec3(1.0);

    if (diffLit) {
        vec3 pos        = get_shadowcoord(viewpos, bias, warp);
        #ifdef shadowfilter_hq
            float s0        = get_softshadow_hq(shadowtex0, pos);
            float s1        = get_softshadow_hq(shadowtex1, pos);
        #else
            float s0        = get_softshadow(shadowtex0, pos);
            float s1        = get_softshadow(shadowtex1, pos);
        #endif

        bool translucent = distance(s0, s1)>0.1;

        shadow          = s1;

        if (translucent) {
            shadowcol   = get_shadowcol(shadowcolor0, pos.xy);
        }
        shadowcol       = to_linear(shadowcol);
    }
}
#else
void get_ldirect(out float shadow, out vec3 shadowcol, bool diffLit) {
    shadow              = 1.0;
    shadowcol           = vec3(1.0);

    if (diffLit) {
        vec3 pos        = pos_shadow;
        #ifdef shadowfilter_hq
            float s0        = get_softshadow_hq(shadowtex0, pos);
            float s1        = get_softshadow_hq(shadowtex1, pos);
        #else
            float s0        = get_softshadow(shadowtex0, pos);
            float s1        = get_softshadow(shadowtex1, pos);
        #endif

        bool translucent = distance(s0, s1)>0.1;

        shadow          = s1;

        if (translucent) {
            shadowcol   = get_shadowcol(shadowcolor0, pos.xy);
        }
        shadowcol       = to_linear(shadowcol);
    }
}
#endif