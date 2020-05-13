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

uniform sampler2D colortex3;

uniform vec2 pixelSize;
uniform vec2 viewSize;

in vec2 coord;

#if pass == 0
    //horizontal gauss and downsampling

    vec2 rscale     = vec2(1920.0, 1080.0)/max(viewSize, vec2(1920.0, 1080.0));

    vec3 gauss_1d(vec2 coord, vec2 dir, float alpha, int steps) {
        vec4 result     = vec4(0.0);
        float maxcoord  = 0.25*rscale.x;
        float mincoord  = 0.0;

        //steps *= 2;

        for (int i = -steps; i<steps+1; i++) {
            float weight    = exp(-i*i*alpha*4.0);
            vec2 spcoord    = coord+dir*pixelSize*(i*2.0);
            result         += vec4(texture(colortex3, spcoord).rgb, 1.0)*weight*float(spcoord.x>mincoord && spcoord.x<maxcoord);
        }
        return result.rgb/max(1.0, result.a);
    }

    void main() {
        if (clamp(coord, -0.003, 1.003) != coord) discard;
        vec2 tcoord     = (gl_FragCoord.xy*vec2(2.0, 4.0)*pixelSize);
        vec2 gaussdir   = vec2(1.0, 0.0);
        vec3 blur       = vec3(0.0);

        vec2 tc2        = tcoord*vec2(2.0, 1.0)/2.0;
        if (tc2.x<1.0*rscale.x && tc2.y<1.0*rscale.y)
        blur  = gauss_1d(tc2/2.0, gaussdir, 0.16, 0);

        vec2 tc4        = tcoord*vec2(4.0, 1.0)/2.0-vec2(0.5*rscale.x+4.0*pixelSize.x, 0.0)*2.0;
        if (tc4.x>0.0 && tc4.y>0.0 && tc4.x < 1.0*rscale.x && tc4.y < 1.0*rscale.y)
        blur  = gauss_1d(tc4/2.0, gaussdir, 0.16, 3);

        vec2 tc8        = tcoord*vec2(8.0, 1.0)/2.0-vec2(0.75*rscale.x+8.0*pixelSize.x, 0.0)*4.0;
        if (tc8.x>0.0 && tc8.y>0.0 && tc8.x < 1.0*rscale.x && tc8.y < 1.0*rscale.y)
        blur  = gauss_1d(tc8/2.0, gaussdir, 0.035, 6);

        //1:64
        vec2 tc16       = tcoord*vec2(8.0, 1.0/2.0)-vec2(0.875*rscale.x+12.0*pixelSize.x, 0.0)*8.0;
        if (tc16.x>0.0 && tc16.y>0.0 && tc16.x < 1.0*rscale.x && tc16.y < 1.0*rscale.y)
        blur  = gauss_1d(tc16/2.0, gaussdir, 0.0085, 12);

        vec2 tc32       = tcoord*vec2(16.0, 1.0/2.0)-vec2(0.9375*rscale.x+16.0*pixelSize.x, 0.0)*16.0;
        if (tc32.x>0.0 && tc32.y>0.0 && tc32.x < 1.0*rscale.x && tc32.y < 1.0*rscale.y)
        blur  = gauss_1d(tc32/2.0, gaussdir, 0.002, 28);

        vec2 tc64       = tcoord*vec2(32.0, 1.0/2.0)-vec2(0.96875*rscale.x+20.0*pixelSize.x, 0.0)*32.0;
        if (tc64.x>0.0 && tc64.y>0.0 && tc64.x < 1.0*rscale.x && tc64.y < 1.0*rscale.y)
        blur  = gauss_1d(tc64/2.0, gaussdir, 0.0005, 60);

        /*DRAWBUFFERS:3*/
        gl_FragData[0]  = clampDrawbuffer(blur);
    }
#elif pass == 1
    //vertical gauss and downsampling

    uniform float aspectRatio;

    vec2 rscale     = vec2(1920.0, 1080.0)/max(viewSize, vec2(1920.0, 1080.0));

    vec3 gauss_1d(vec2 coord, vec2 dir, float alpha, int steps) {
        vec4 result     = vec4(0.0);
        float maxcoord  = 0.25*rscale.y;
        float mincoord  = 0.0;

        //steps *= 2;

        for (int i = -steps; i<steps+1; i++) {
            float weight    = exp(-i*i*alpha*4.0);
            vec2 spcoord    = coord+dir*pixelSize*(i*2.0);
            result         += vec4(texture(colortex3, spcoord).rgb, 1.0)*weight*float(spcoord.y>mincoord && spcoord.y<maxcoord);
        }
        return result.rgb/max(1.0, result.a);
    }

    void main() {
        if (clamp(coord, -0.003, 1.003) != coord) discard;
        vec2 tcoord     = (gl_FragCoord.xy*vec2(2.0, 4.0)*pixelSize);
        vec2 gaussdir   = vec2(0.0, 1.0);
        vec3 blur       = vec3(0.0);

        if (gl_FragCoord.y*pixelSize.y > 0.22) blur = texture(colortex3, gl_FragCoord.xy*pixelSize).rgb; 

        vec2 tc2        = tcoord*vec2(2.0, 1.0);
        if (tc2.x<1.0*rscale.x && tc2.y<1.0*rscale.y)
        blur  = gauss_1d(tcoord/vec2(2.0, 4.0), gaussdir, 0.16, 0);

        vec2 tc4        = tcoord*vec2(4.0, 2.0)-vec2(0.5*rscale.x+4.0*pixelSize.x, 0.0)*4.0;
        if (tc4.x>0.0 && tc4.y>0.0 && tc4.x<1.0*rscale.x && tc4.y<1.0*rscale.y)
        blur  = gauss_1d(tcoord/vec2(2.0), gaussdir, 0.16, 3);

        vec2 tc8        = tcoord*vec2(8.0, 4.0)-vec2(0.75*rscale.x+8.0*pixelSize.x, 0.0)*8.0;
        if (tc8.x>0.0 && tc8.y>0.0 && tc8.x<1.0*rscale.x && tc8.y<1.0*rscale.y)
        blur  = gauss_1d(tcoord*vec2(1.0, 2.0)/vec2(2.0), gaussdir, 0.035, 6);

        //1:64
        vec2 tc16       = tcoord*vec2(16.0, 8.0)-vec2(0.875*rscale.x+8.0*pixelSize.x, 0.0)*16.0;
        if (tc16.x>0.0 && tc16.y>0.0 && tc16.x<1.0*rscale.x && tc16.y<1.0*rscale.y)
        blur  = gauss_1d(tcoord*vec2(1.0, 4.0)/vec2(2.0), gaussdir, 0.0085, 12);

        vec2 tc32       = tcoord*vec2(32.0, 16.0)-vec2(0.9375*rscale.x+16.0*pixelSize.x, 0.0)*32.0;
        if (tc32.x>0.0 && tc32.y>0.0 && tc32.x<1.0*rscale.x && tc32.y<1.0*rscale.y)
        blur  = gauss_1d(tcoord*vec2(1.0, 8.0)/vec2(2.0), gaussdir, 0.002, 30);

        vec2 tc64       = tcoord*vec2(64.0, 32.0)-vec2(0.96875*rscale.x+20.0*pixelSize.x, 0.0)*64.0;
        if (tc64.x>0.0 && tc64.y>0.0 && tc64.x<1.0*rscale.x && tc64.y<1.0*rscale.y)
        blur  = gauss_1d(tcoord*vec2(1.0, 16.0)/vec2(2.0), gaussdir, 0.0005, 60);

        /*DRAWBUFFERS:3*/
        gl_FragData[0]  = clampDrawbuffer(blur);
    }
#endif