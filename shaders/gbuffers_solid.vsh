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

out mat2x2 coord;

out vec4 tint;

flat out vec3 normal;

uniform vec2 taaOffset;

uniform mat4 gbufferModelView, gbufferModelViewInverse;

#ifdef g_terrain
    flat out int foliage;

    flat out int mat_id;

    uniform vec3 cameraPosition;

    attribute vec4 mc_Entity;
    attribute vec4 mc_midTexCoord;

    #ifdef wind_effects_enabled
        #include "/lib/vert/wind.glsl"
    #endif
#endif

void main() {
    coord[0]    = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    coord[1]    = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    coord[1].x  = linStep(coord[1].x, rcp(24.0), 1.0);
    coord[1].y  = linStep(coord[1].y, rcp(16.0), 1.0);

    normal      = mat3(gbufferModelViewInverse)*normalize(gl_NormalMatrix*gl_Normal);
    tint        = gl_Color;

    vec4 pos    = gl_Vertex;
        pos     = viewMAD(gl_ModelViewMatrix, pos.xyz).xyzz;

    #if (defined g_terrain && defined wind_effects_enabled)
        pos.xyz = viewMAD(gbufferModelViewInverse, pos.xyz);

        bool windLod    = length(pos.xz) < 192.0;

        if (windLod) {
            bool topvert    = (gl_MultiTexCoord0.t < mc_midTexCoord.t);

            float occlude   = sqr(coord[1].y)*0.9+0.1;

            if (mc_Entity.x == 10021 || (mc_Entity.x == 10022 && topvert) || (mc_Entity.x == 10023 && topvert) || mc_Entity.x == 10024) {
                vec2 wind_offset = wind_effect(pos.xyz + cameraPosition, 0.18, 1.0)*occlude;

                if (mc_Entity.x == 10021) pos.xyz += wind_offset.xyy*0.4;
                else if (mc_Entity.x == 10023 || (mc_Entity.x == 10024 && !topvert)) pos.xz += wind_offset*0.5;
                else pos.xz += wind_offset;
            }
        }

        pos.xyz = viewMAD(gbufferModelView, pos.xyz);
    #endif

        pos     = pos.xyzz * diag4(gl_ProjectionMatrix) + vec4(0.0, 0.0, gl_ProjectionMatrix[3].z, 0.0);

    #ifdef taa_enabled
        pos.xy += taaOffset*pos.w;
    #endif
        
    gl_Position = pos;

    #ifdef g_terrain
        mat_id  = 1;

        if (
         mc_Entity.x == 10022 ||
         mc_Entity.x == 10023 ||
         mc_Entity.x == 10024 ||
         mc_Entity.x == 10025) mat_id = 2;

        if (
         mc_Entity.x == 10021) mat_id = 4;
    #endif
}