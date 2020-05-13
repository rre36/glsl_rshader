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

out vec2 coord;
uniform vec2 viewSize;

#if pass == 0
    void main() {
        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);

        vec2 cres   = max(viewSize, vec2(1920.0, 1080.0));

        gl_Position.xy = (gl_Position.xy*0.5+0.5)*0.52/cres*vec2(1920.0, 1080.0)*2.0-1.0+vec2(0.0, 0.49);

        coord = gl_MultiTexCoord0.xy;
    }
#elif pass == 1
    void main() {
        gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);

        vec2 cres   = max(viewSize, vec2(1920.0, 1080.0));

        gl_Position.xy = (gl_Position.xy*0.5+0.5)*0.26/cres*vec2(1920.0, 1080.0)*2.0-1.0;

        coord = gl_MultiTexCoord0.xy;
    }
#endif