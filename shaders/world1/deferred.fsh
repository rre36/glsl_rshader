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

/*
stand in for sky pass
*/

/*
const int colortex0Format   = RGBA16F;
const int colortex1Format   = RGBA16;
const int colortex2Format   = RG16;
const int colortex3Format   = RGBA16F;
const int colortex4Format   = RGBA16F;  

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

c0  - 4x16 scene color (full)
c1  - 1x16 encoded normals, 1x16 lightmaps, 2x16 specular texture (gbuffer -> composite2)
c2  - 1x16 matID, 1x16 translucency albedo hue  (gbuffer -> composite2)
c3  - 4x16 translucencies  (water -> composite0), bloom (composite7 -> final)
c4  - temporals (full)
*/

const int noiseTextureResolution = 256;

in vec2 coord;

flat in mat3x3 lightColor;

uniform sampler2D colortex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform float aspectRatio;
uniform float far, near;

uniform vec3 upvec, upvecView;
uniform vec3 sunvec, sunvecView;
uniform vec3 moonvec, moonvecView;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

vec3 screen_viewspace(vec3 screenpos, mat4 projInv) {
    screenpos   = screenpos*2.0-1.0;

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

/* ------ ambient occlusion and gi ------ */

#include "/lib/light/ao.glsl"

#define noise_2d_only
#include "/lib/frag/noise.glsl"

vec3 get_stars(vec3 spos, vec3 svec) {
    vec3 plane  = svec/(svec.y+length(svec.xz)*0.66);
        if (svec.y < 0.0) plane  = (-svec)/(-svec.y+length(svec.xz)*0.66);
    //float rot   = worldTime*rcp(2400.0);
    //plane.x    += rot*0.6;
    //plane.yz    = rotate_coord(plane.yz, (25.0/180.0)*pi);
    vec2 uv1    = floor((plane.xz)*768)/768;
    vec2 uv2    = (plane.xz)*0.04;

    vec3 starcol = vec3(0.5, 0.68, 1.0);
        starcol  = mix(starcol, vec3(1.0, 0.7, 0.6), noise_2d(uv2).x);
        starcol  = normalize(starcol)*(noise_2d(uv2*1.5).x+1.0);

    float star  = 1.0;
        star   *= noise_2d(uv1).x;
        star   *= noise_2d(uv1+0.1).x;
        star   *= noise_2d(uv1+0.26).x;

    star        = max(star-0.25, 0.0);
    star        = saturate(star*4.0);

    return star*starcol*2.0;
}

void main() {
    vec4 scenecol   = stex(colortex0);
    float scenedepth = stex(depthtex1).x;

    vec3 viewpos    = screen_viewspace(vec3(coord, scenedepth));
    vec3 viewvec    = normalize(viewpos);
    vec3 scenepos   = view_scenespace(viewpos);
    vec3 svec       = normalize(scenepos);

    if (!landMask(scenedepth)) {
        scenecol.rgb = get_stars(scenepos, svec);
    }

    vec4 return3    = vec4(0.0);

    #ifdef ambientOcclusion_enabled
        vec2 ao_coord   = (coord)*2.0;

        if (clamp(ao_coord, -0.003, 1.003) == ao_coord) {
            vec2 coord  = ao_coord;
            float scenedepth = stex(depthtex1).x;
            float ao    = calculate_dbao(depthtex1, scenedepth, coord);
            return3.x   = ao;
        }
    #endif

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
    gl_FragData[1]  = clampDrawbuffer(return3);
}