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
#include "/lib/util/encoders.glsl"
#include "/lib/util/srgb.glsl"

const int shadowMapResolution   = 2560;     //[512 1024 1536 2048 2560 3072 3584 4096 6144 8192 16384]
const float shadowDistance      = 128.0;

const bool shadowHardwareFiltering = true;

in vec2 coord;

flat in mat3x3 lightColor;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D noisetex;

uniform sampler2D depthtex1;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

uniform int frameCounter;

uniform float aspectRatio;
uniform float far, near;
uniform float sunAngle;
uniform float viewHeight, viewWidth;

uniform vec2 taaOffset;
uniform vec2 viewSize;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;

vec3 screen_viewspace(vec3 screenpos, mat4 projInv) {
    screenpos   = screenpos*2.0-1.0;

    screenpos.xy -= taaOffset;

    vec3 viewpos    = vec3(vec2(projInv[0].x, projInv[1].y)*screenpos.xy + projInv[3].xy, projInv[3].z);
        viewpos    /= projInv[2].w*screenpos.z + projInv[3].w;
    
    return viewpos;
}

vec3 screen_viewspace(vec3 screenpos) {
    return screen_viewspace(screenpos, gbufferProjectionInverse);
}

vec3 view_scenespace(vec3 viewpos, mat4 mvInv) {
    return viewMAD(mvInv, viewpos);
}

vec3 view_scenespace(vec3 viewpos) {
    return view_scenespace(viewpos, gbufferModelViewInverse);
}

float depth_lin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}

vec2 rotate_coord(vec2 pos, const float angle) {
    return vec2(cos(angle)*pos.x + sin(angle)*pos.y, 
                cos(angle)*pos.y - sin(angle)*pos.x);
}

vec3 lightvec     = normalize(vec3(0.0, 1.0, 0.0));

#include "/lib/light/diffuse.glsl"

#include "/lib/light/warp.glsl"

float ditherBluenoise() {
    ivec2 coord = ivec2(fract(gl_FragCoord.xy/256.0)*256.0);
    float noise = texelFetch(noisetex, coord, 0).a;
        noise   = fract(noise+float(frameCounter)/4.0);

    return noise;
}

#define g_solid

#include "/lib/light/shadow.glsl"

vec3 get_lblock(vec3 lcol, float lmap) {
    return pow5(lmap)*lcol;
}

vec3 get_light(vec3 scenecol, vec3 normal, vec3 viewpos, vec2 lmap, float ao, int matID) {
    float shadow    = 1.0;
    vec3 shadowcol  = vec3(1.0);

        lightvec.yz     = rotate_coord(lightvec.yz, radians(sunPathRotation));
        lightvec        = normalize(lightvec);

    float diff      = get_diffLambert(normal);
        diff        = matID != 2 ? diff : diff*0.3+0.7;

    get_ldirect(shadow, shadowcol, diff>0.0, viewpos);

    float diff_lit  = min(diff, shadow);
    vec3 direct_col     = lightColor[0];
    vec3 direct_light   = diff_lit*shadowcol*direct_col;
    vec3 indirect_light = lightColor[1];
        indirect_light *= ao;

    vec3 result     = direct_light + indirect_light;
        result     += get_lblock(lightColor[2], lmap.x)*ao;

    return scenecol * result;
}

int decodeMatID16(float x) {
    return int(x*65535.0);
}

vec4 textureBilateral(sampler2D tex, sampler2D depth, const int lod, float fdepth) {
    vec4 data   = vec4(0.0);
    float sum   = 0.0;
    ivec2 posD  = ivec2(coord*viewSize);
    ivec2 posT  = ivec2(coord*viewSize*rcp(float(lod)));
    vec3 zmult  = vec3((far*near)*2.0, far+near, far-near);
        fdepth  = depth_lin(fdepth);
    
    for (int i = -1; i<2; i++) {
        for (int j = -1; j<2; j++) {
            ivec2 tcDepth = posD + ivec2(i, j)*lod;
            float dsample = depth_lin(texelFetch(depth, tcDepth, 0).x);
            float w     = abs(dsample-fdepth)*zmult.x<1.0 ? 1.0 : 1e-5;
            ivec2 ct    = posT + ivec2(i, j);
            data       += texelFetch(tex, ct, 0)*w;
            sum        += w;
        }
    }
    data *= rcp(sum);

    return data;
}

void main() {
    vec4 scenecol   = stex(colortex0);
    float scenedepth = stex(depthtex1).x;

    if (landMask(scenedepth)) {
        vec4 tex1       = stex(colortex1);
        vec2 scenelmap  = decode2x8(tex1.z);
        vec3 scenenormal = decodeNormal(tex1.xy);

        vec4 tex2       = stex(colortex2);
        int matID       = decodeMatID16(tex2.x);

        #if DEBUG_VIEW==1
        scenecol.rgb    = vec3(1.0);
        #endif

        vec3 viewpos    = screen_viewspace(vec3(coord, scenedepth));

        float ao        = sqr(scenecol.a)*0.66+0.34;

        #ifdef ambientOcclusion_enabled
            vec4 tex3   = textureBilateral(colortex3, depthtex1, 2, scenedepth);
                ao     *= tex3.r;
        #endif

        scenecol.rgb    = get_light(scenecol.rgb, scenenormal, viewpos, scenelmap, ao, matID);

        #if DEBUG_VIEW==2
        scenecol.rgb    = ao * (sunAngle<0.5 ? lightColor[0] : lightColor[3]);
        #endif
    }

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
    gl_FragData[1]  = vec4(0.0);
}