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

flat in float light_flip;

flat in mat4x3 lightColor;

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

uniform vec3 lightvec, lightvecView;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;

#include "/lib/util/transforms.glsl"

float depth_lin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}

#include "/lib/light/diffuse.glsl"

#include "/lib/light/warp.glsl"

#include "/lib/frag/bluenoise.glsl"

#define g_solid

#include "/lib/light/shadow.glsl"

vec3 get_lblock(vec3 lcol, float lmap) {
    return pow5(lmap)*lcol;
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
        scenecol.rgb    = vec3(0.25);
        #endif

        vec3 viewpos    = screen_viewspace(vec3(coord, scenedepth));

        float ao        = pow3(scenecol.a)*0.95+0.05;
        
        #ifdef ambientOcclusion_enabled
            vec4 tex3   = textureBilateral(colortex3, depthtex1, 2, scenedepth);
                ao     *= tex3.r;
        #endif

        //scenecol.rgb    = get_light(scenecol.rgb, scenenormal, viewpos, scenelmap, ao, matID);
        
        /* ------ lighting calculation ------ */
        //~6 fps
        
        vec2 lmap       = scenelmap;
        float shadow    = 1.0;
        vec3 shadowcol  = vec3(1.0);
        lmap.y          = pow3(lmap.y);

        float diff      = get_diffLambert(scenenormal);
            if (matID == 2) diff = diff*0.3+0.7;
            if (matID == 4) diff = sqrt(diff);

        get_ldirect(shadow, shadowcol, diff>0.0, viewpos);    //~3fps, almost for free

        float diff_lit  = min(diff, shadow);
        vec3 direct_col     = sunAngle<0.5 ? lightColor[0] : lightColor[3];
        vec3 direct_light   = diff_lit*shadowcol*direct_col*light_flip;
        vec3 indirect_light = lmap.y*lightColor[1];
            indirect_light += vec3(0.5, 0.7, 1.0) * (0.04 * minlight_luma);

        vec3 result     = (direct_light + indirect_light) * ao;
            result     += get_lblock(lightColor[2], lmap.x)*ao;

        scenecol.rgb   *= result;

        #if DEBUG_VIEW==2
        scenecol.rgb    = ao * (sunAngle<0.5 ? lightColor[0] : lightColor[3]);
        #endif
    }

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
    gl_FragData[1]  = vec4(0.0);
}