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

out mat2x2 coord;

out vec4 tint;

flat out int mat_id;

flat out vec3 normal;

uniform vec2 taaOffset;

uniform vec3 lightvec, lightvecView;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

attribute vec4 mc_Entity;

#include "/lib/atmos/colors_n.glsl"

void main() {
    coord[0]    = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    coord[1]    = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    coord[1].x  = linStep(coord[1].x, rcp(24.0), 1.0);
    coord[1].y  = linStep(coord[1].y, rcp(16.0), 1.0);

    normal      = mat3(gbufferModelViewInverse)*normalize(gl_NormalMatrix*gl_Normal);
    tint        = gl_Color;

    vec4 pos    = gl_Vertex;
        pos     = viewMAD(gl_ModelViewMatrix, pos.xyz).xyzz;
        pos     = pos.xyzz * diag4(gl_ProjectionMatrix) + vec4(0.0, 0.0, gl_ProjectionMatrix[3].z, 0.0);
        
    #ifdef taa_enabled
        pos.xy += taaOffset*pos.w;
    #endif
        
    gl_Position = pos;

    make_colors();

    //mat ids
    if (mc_Entity.x == 1) mat_id = 102;
    else mat_id = 101;
}