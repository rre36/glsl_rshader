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

in vec2 coord;

flat in mat2x3 light_color;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D depthtex1;

uniform float aspectRatio;
uniform float far, near;
uniform float sunAngle;

uniform vec2 taaOffset;
uniform vec2 viewSize;

uniform vec3 lightvec, lightvecView;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

#include "/lib/util/transforms.glsl"

float depth_lin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}

vec3 get_lblock(vec3 lcol, float lmap) {
    return pow5(lmap)*lcol;
}

vec3 get_light(vec3 scenecol, vec2 lmap, float ao, int matID) {
    float shadow    = 1.0;
    vec3 shadowcol  = vec3(1.0);
    lmap.y          = pow3(lmap.y);

    vec3 indirect_light = light_color[0];
        indirect_light += vec3(0.5, 0.7, 1.0)*0.01*minlight_luma;
        indirect_light *= ao;

    vec3 result     = indirect_light;
        result     += get_lblock(light_color[1], lmap.x)*ao;

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
    //ivec2 p     = (ivec2(gl_FragCoord.xy + frameCounter) % 2 - 1)*0;
    
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

        vec4 tex2       = stex(colortex2);
        int matID       = decodeMatID16(tex2.x);

        #if DEBUG_VIEW==1
        scenecol.rgb    = vec3(1.0);
        #endif

        float ao        = pow2(scenecol.a)*0.8+0.2;

        #ifdef ambientOcclusion_enabled
            vec4 tex3   = textureBilateral(colortex3, depthtex1, 2, scenedepth);
                ao     *= tex3.r;
        #endif

        scenecol.rgb    = get_light(scenecol.rgb, scenelmap, ao, matID);

        #if DEBUG_VIEW==2
        scenecol.rgb    = ao * light_color[0] * 2.0;
        #endif
    }

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
    gl_FragData[1]  = vec4(0.0);
}