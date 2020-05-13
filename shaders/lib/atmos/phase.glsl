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

float rayleigh_phase(float cosTheta) {
    float phase = 0.8 * (1.4 + 0.5 * cosTheta);
    phase *= rcp(pi*4);
  	return phase;
}

float hg_mie(float cosTheta, float g) {
    float mie   = 1.0 + pow2(g) - 2.0*g*cosTheta;
        mie     = (1.0 - pow2(g)) / ((4.0*pi) * mie*(mie*0.5+0.5));
    return mie;
}

float cs_mie(float cosTheta, float g) {
  	float gg = g*g;
  	float p1 = 3.0 * (1.0 - gg) * rcp((pi * (2.0 + gg)));
  	float p2 = (1.0 + pow2(cosTheta)) * rcp(pow((1.0 + gg - 2.0 * g * cosTheta), 3.0/2.0));
  	float phase = p1 * p2;
  	phase *= rcp(pi*4);
  	return max(phase, 0.0);
}