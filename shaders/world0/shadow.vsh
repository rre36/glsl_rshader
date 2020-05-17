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

out vec2 coord;

out vec4 tint;

flat out int mat_id;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

#include "/lib/light/warp.glsl"

uniform vec3 cameraPosition;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

#ifdef wind_effects_enabled
    #include "/lib/vert/wind.glsl"

float value_3d_w(vec3 pos) {
    vec3 p  = floor(pos); 
    vec3 b  = fract(pos);

    vec2 uv = (p.xy+vec2(-97.0)*p.z)+b.xy;
    vec2 rg = texture(noisetex, (uv)/256.0).xy;

    return cubeSmooth(mix(rg.x, rg.y, b.z));
}

float water_wave(vec3 pos, const float size) {
    vec3 p  = pos * size;

    float t = frameTimeCounter * pi * 0.5;
    vec3 w  = vec3(t*0.9, t*0.2, t*0.3);

    float wave  = value_3d_w(p + w);
        p.xz    = rotate_coord(p.xz, 0.4 * pi);
        wave   += value_3d(p * 2.0 + w) * 0.5;
        wave   -= 0.75;

    return wave*0.2;
}
#endif

void main() {
    coord    = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;

    tint        = gl_Color;

    vec4 pos    = gl_Vertex;
        pos     = gl_ModelViewMatrix * pos;

    #ifdef wind_effects_enabled
        pos.xyz = viewMAD(shadowModelViewInverse, pos.xyz);

        bool windLod    = length(pos.xz) < 64.0;

        if (windLod) {
            float slmap  = linStep((gl_TextureMatrix[1]*gl_MultiTexCoord1).y, rcp(16.0), 1.0);
            bool topvert    = (gl_MultiTexCoord0.t < mc_midTexCoord.t);

            float occlude   = sqr(slmap)*0.9+0.1;

            if (mc_Entity.x == 10001) pos.y += water_wave(pos.xyz + cameraPosition, 0.55);

            if (mc_Entity.x == 10021 || (mc_Entity.x == 10022 && topvert) || (mc_Entity.x == 10023 && topvert) || mc_Entity.x == 10024) {
                vec2 wind_offset = wind_effect(pos.xyz + cameraPosition, 0.18, 1.0)*occlude;

                if (mc_Entity.x == 10021) pos.xyz += wind_offset.xyy*0.4;
                else if (mc_Entity.x == 10023 || (mc_Entity.x == 10024 && !topvert)) pos.xz += wind_offset*0.5;
                else pos.xz += wind_offset;
            }
        }

        pos.xyz = viewMAD(shadowModelView, pos.xyz);
    #endif

        pos     = gl_ProjectionMatrix * pos;

        pos.xy  = warp_shadowmap(pos.xy);
        pos.z  *= 0.2;

    gl_Position = pos;

    //mat ids
    if (mc_Entity.x == 10001) mat_id = 102;
    else mat_id = 1;
}