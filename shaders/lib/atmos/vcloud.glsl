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

float cloud_phase(float cos_theta, float g) {
    float a     = cloud_mie_dumb(cos_theta, 0.89*g) * 1.0;
    float b     = cloud_mie(cos_theta, -0.25*g) * 1.35;

    return mix(a, b, 0.38) + 0.1;
}

const float vcloud_maxalt   = vcloud_alt + vcloud_depth;
const float vcloud_midalt   = vcloud_alt + vcloud_depth * 0.5;
const float vcloud_size     = 0.004;

#define vc_powder_K 30.0

float vcloud_shape(vec3 pos) {
    vec3 pos0 = pos * vcloud_size;

    float tick  = frameTimeCounter * 0.4;

    pos0.x  += tick*0.02;

    pos0    += (value_3d(pos0+vec3(0.0, tick*0.01, 0.0))*2.0-1.0)*0.4;

    //vec3 pos1   = pos0*vec3(1.0, 0.5, 1.0)+vec3(0.0, tick*0.01, 0.0);

    float coverage    = mix(0.5, 0.8, wetness);

    const float nf    = 1.325;
    float threshold   = (1.0 - coverage) * nf * 0.95;

    float noise = value_3d(pos0*vec3(1.0, 0.5, 1.0) + vec3(0.0, tick*0.01, 0.0));
    if (noise < (threshold - 0.325)) return 0.0;
        pos0 *= 4.0; pos0.x -= tick*0.02;
        noise  += (1.0 - abs(value_3d(pos0)*3.0-1.0))*0.2;
    if (noise < (threshold - 0.125)) return 0.0;
        pos0 *= 4.0; pos0.x -= tick*0.05;
        noise  += (1.0 - abs(value_3d(pos0)*3.0-1.0))*0.075;
    if (noise < (threshold - 0.05)) return 0.0;
        pos0 *= 2.0; pos0.x -= tick*0.05;
        noise  += (1.0 - abs(value_3d(pos0)*3.0-1.0))*0.05;
        //pos0 *= 3.0;
        //noise  += (1.0 - abs(value_3d(pos0)*3.0-1.0))*0.035;
        noise  /= nf;
        
    float shape = noise;

    float altWeight = 1.0 - saturate(distance(pos.y, vcloud_midalt)/(vcloud_depth*0.5));
        altWeight   = sqrt(sqrt(altWeight));

        shape *= altWeight;

        shape       = max(shape-(1.0-coverage), 0.0);

    return max(shape, 0.0);
}

float vc_directOD(in vec3 pos, const int steps) {
    vec3 dir    = cloud_lvec;

    float stepsize = (vcloud_depth / steps);

    float od = 0.0;
    for(int i = 0; i < steps; ++i, pos += dir * stepsize) {
        if(pos.y > vcloud_maxalt || pos.y < vcloud_alt) continue;

        float density = vcloud_shape(pos);
        od += density*stepsize;
    } 

    return od;
}
float vc_skyOD(in vec3 pos, const int steps) {
    vec3 dir    = vec3(0.0, 1.0, 0.0);

    float stepsize = (vcloud_depth / steps);
        stepsize  *= (1.0-linStep(pos.y, vcloud_alt, vcloud_maxalt))*0.9+0.1;

    float od = 0.0;
    for(int i = 0; i < steps; ++i, pos += dir * stepsize) {
        if(pos.y > vcloud_maxalt || pos.y < vcloud_alt) break;

        float density = vcloud_shape(pos);
        od += density*stepsize;
    } 

    return od;
}