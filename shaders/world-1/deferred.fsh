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

in vec2 coord;

flat in mat2x3 lightColor;
flat in vec3 sky_color;

uniform sampler2D colortex0;
uniform sampler2D depthtex1;

uniform float aspectRatio;
uniform float far, near;

uniform mat4 gbufferProjection;

float depth_lin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}

/* ------ ambient occlusion and gi ------ */

#include "/lib/light/ao.glsl"

void main() {
    vec4 scenecol   = stex(colortex0);
    float scenedepth = stex(depthtex1).x;

    if (!landMask(scenedepth)) {
        scenecol.rgb = sky_color;
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