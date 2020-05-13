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

//bloom downsampling method based on chocapic13's shaders

uniform vec2 pixelSize;
uniform vec2 viewSize;

in vec2 coord;

#if pass == 0
    uniform sampler2D colortex0;

    void main() {
        if (clamp(coord, -0.003, 1.003) != coord) discard;
        vec2 rscale     = max(viewSize, vec2(1920.0, 1080.0))/vec2(1920.0, 1080.0);
        vec2 qrescoord  = (gl_FragCoord.xy*2.0*pixelSize-vec2(0.0, 0.5))*rscale;

        //0.5
        vec4 blur       = texture(colortex0, qrescoord-1.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.5;
            blur       += texture(colortex0, qrescoord+1.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.5;
            blur       += texture(colortex0, qrescoord+1.0*vec2(-pixelSize.x, pixelSize.y))/4.0*0.5;
            blur       += texture(colortex0, qrescoord+1.0*vec2(pixelSize.x, -pixelSize.y))/4.0*0.5;

        //0.25
            blur       += texture(colortex0, qrescoord-2.0*vec2(pixelSize.x, 0.0))/2.0*0.125;
            blur       += texture(colortex0, qrescoord+2.0*vec2(0.0, pixelSize.y))/2.0*0.125;
            blur       += texture(colortex0, qrescoord+2.0*vec2(-pixelSize.x, 0.0))/2.0*0.125;
            blur       += texture(colortex0, qrescoord+2.0*vec2(0.0, -pixelSize.y))/2.0*0.125;

        //0.125
            blur       += texture(colortex0, qrescoord-2.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.125;
            blur       += texture(colortex0, qrescoord+2.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.125;
            blur       += texture(colortex0, qrescoord+2.0*vec2(-pixelSize.x, pixelSize.y))/4.0*0.125;
            blur       += texture(colortex0, qrescoord+2.0*vec2(pixelSize.x, -pixelSize.y))/4.0*0.125;

            blur       += texture(colortex0, qrescoord)*0.125;

            if (qrescoord.x>1.0-3.5*pixelSize.x || qrescoord.y>1.0-3.5*pixelSize.y || qrescoord.x<3.5*pixelSize.x || qrescoord.y<3.5*pixelSize.y) blur = vec4(0.0);
            blur.a  = 1.0;

        /*DRAWBUFFERS:3*/
        gl_FragData[0]  = clampDrawbuffer(blur);
    }
#elif pass == 1
    uniform sampler2D colortex3;

    void main() {
        if (clamp(coord, -0.003, 1.003) != coord) discard;
        vec2 rscale     = max(viewSize, vec2(1920.0, 1080.0))/vec2(1920.0, 1080.0);
        vec2 qrescoord  = gl_FragCoord.xy*2.0*pixelSize+vec2(0.0, 0.25);

        //0.5
        vec4 blur       = texture(colortex3, qrescoord-1.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.5;
            blur       += texture(colortex3, qrescoord+1.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.5;
            blur       += texture(colortex3, qrescoord+1.0*vec2(-pixelSize.x, pixelSize.y))/4.0*0.5;
            blur       += texture(colortex3, qrescoord+1.0*vec2(pixelSize.x, -pixelSize.y))/4.0*0.5;

        //0.25
            blur       += texture(colortex3, qrescoord-2.0*vec2(pixelSize.x, 0.0))/2.0*0.125;
            blur       += texture(colortex3, qrescoord+2.0*vec2(0.0, pixelSize.y))/2.0*0.125;
            blur       += texture(colortex3, qrescoord+2.0*vec2(-pixelSize.x, 0.0))/2.0*0.125;
            blur       += texture(colortex3, qrescoord+2.0*vec2(0.0, -pixelSize.y))/2.0*0.125;

        //0.125
            blur       += texture(colortex3, qrescoord-2.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.125;
            blur       += texture(colortex3, qrescoord+2.0*vec2(pixelSize.x, pixelSize.y))/4.0*0.125;
            blur       += texture(colortex3, qrescoord+2.0*vec2(-pixelSize.x, pixelSize.y))/4.0*0.125;
            blur       += texture(colortex3, qrescoord+2.0*vec2(pixelSize.x, -pixelSize.y))/4.0*0.125;

            blur       += texture(colortex3, qrescoord)*0.125;

            //if (qrescoord.x>1.0-3.5*pixelSize.x || qrescoord.y>1.0-3.5*pixelSize.y || qrescoord.x<3.5*pixelSize.x || qrescoord.y<3.5*pixelSize.y) blur = vec4(0.0);
            blur.a  = 1.0;

        /*DRAWBUFFERS:3*/
        gl_FragData[0]  = clampDrawbuffer(blur);
    }
#endif