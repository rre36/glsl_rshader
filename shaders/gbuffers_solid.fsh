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

flat in vec3 normal;

#ifdef g_textured
    uniform sampler2D gcolor;
#endif

float encodeMatID16(int x) {
    float id    = float(x)/65535.0;
    return id;
}

#ifdef g_terrain
flat in int foliage;
flat in int mat_id;
#endif

#ifdef g_entity
uniform vec4 entityColor;
#endif

void main() {
    #ifdef g_textured
        vec4 scenecol   = texture(gcolor, coord[0]);
        if (scenecol.a<0.1) discard;
            scenecol.rgb *= tint.rgb;
        
        #ifdef g_terrain
            scenecol.a  = tint.a;
        #else
            scenecol.a  = 1.0;
        #endif

        #ifdef g_entity
            scenecol.rgb = mix(scenecol.rgb, entityColor.rgb, entityColor.a);
        #endif
    #else
        vec4 scenecol   = tint;
        if (scenecol.a<0.01) discard;
            scenecol.a  = 1.0;
    #endif

        scenecol.rgb    = to_linear(scenecol.rgb);

    #ifdef g_terrain
        int matID   = mat_id;
    #else
        #ifdef g_nodiff
        const int matID = 2;
        #else
        const int matID = 1;
        #endif
    #endif

    /*DRAWBUFFERS:012*/
    gl_FragData[0]  = makeDrawbuffer(scenecol.rgb, saturate(scenecol.a));
    gl_FragData[1]  = vec4(encodeNormal(normal), encode2x8(coord[1]), 1.0);
    gl_FragData[2]  = vec4(encodeMatID16(matID), 0.0, 0.0, 0.0);
}