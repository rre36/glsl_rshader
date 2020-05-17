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


float bayer2  (vec2 c) { c = 0.5 * floor(c); return fract(1.5 * fract(c.y) + c.x); }
float bayer4  (vec2 c) { return 0.25 * bayer2 (0.5 * c) + bayer2(c); }
float bayer8  (vec2 c) { return 0.25 * bayer4 (0.5 * c) + bayer2(c); }
float bayer16 (vec2 c) { return 0.25 * bayer8 (0.5 * c) + bayer2(c); }

float calculate_dbao(sampler2D depthtex, float depth, vec2 coord) {
    const int steps     = 3;
    const int ao_area   = 4;
    float dither    = bayer16(gl_FragCoord.xy);
    bool hand       = depth<0.56;
    depth           = depth_lin(depth);
    //ivec2 res       = ivec2(viewWidth, viewHeight);
    //ivec2 coord     = ivec2(coord*res);

    const float pi_angle = 22.0/(7.0*180.0);
    float rot           = 180.0/ao_area*(dither+0.5);
    float radius        = 0.9/steps;

    float ao        = 0.0;
    float size      = pi * rcp(float(steps));
        size       *= dither;
    float angle     = 0.0;
    float sdepth    = 0.0;
    float dist      = 0.0;
    vec2 scale      = size * vec2(rcp(aspectRatio), 1.0) * gbufferProjection[1][1] / (2.74747742 * max(far*depth,6.0));

    for (int i = 0; i < steps; i++) {
        //ivec2 offset = ivec2(offset_dist(i + dither, steps)*scale*res);

        for (int j = 0; j < ao_area; j++) {
            vec2 offset = vec2(cos(rot*pi_angle), sin(rot*pi_angle))*scale;
            sdepth      = depth_lin(texture(depthtex, coord + offset).x);
            float samp  = far*(depth-sdepth)*rcp(size);
            if (hand) samp *= 1024.0;
            angle       = saturate(0.5-samp);
            dist        = saturate(0.0625*samp);

            sdepth      = depth_lin(texture(depthtex, coord - offset, 0).x);
            samp        = far*(depth-sdepth)*rcp(size);
            if (hand) samp *= 1024.0;
            angle      += saturate(0.5-samp);
            dist       += saturate(0.0625*samp);

            ao         += saturate(angle+dist);
            rot        += 180.0 * rcp(float(ao_area));
        }
        rot        += 180.0 * rcp(float(ao_area));
        size       += radius;
        angle       = 0.0;
        dist        = 0.0;
    }
    ao *= rcp(float(steps+ao_area));
    ao  = (ao*(ao))*0.5;
    //ao  = sqrt(ao);

    return saturate(ao);
}

#define ssao_samples 6
#define ssao_radius 1.0

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+19.19);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}

vec3 viewspace_screenspace(vec3 pos) {
	vec3 screenpos  = vec3(gbufferProjection[0].x, gbufferProjection[1].y, gbufferProjection[2].z) * pos + gbufferProjection[3].xyz;
	     screenpos /= -pos.z;

	return screenpos * 0.5 + 0.5;
}

float calculate_ssao(sampler2D depthtex, vec3 viewpos, vec3 viewnormal, float dither) {
    const float dither_size = csqr(32.0) * 16.0;
        dither *= dither_size;
    float result    = 0.0;

    for (float i = 0.0; i <= ssao_samples; i++) {
        vec4 noise  = hash42(vec2(i, dither));
        vec3 offset = normalize(noise.xyz * 2.0 - 1.0) * noise.w;

        if (dot(offset, viewnormal) < 0.0) offset = -offset;

        vec3 sample_pos     = offset * ssao_radius + viewpos;
            sample_pos      = viewspace_screenspace(sample_pos);

        float depth     = texture(depthtex, sample_pos.xy).x;

        if (depth > sample_pos.z) result += 1.1;
    }
    result *= rcp(float(ssao_samples));

    return saturate(pow(result, 1.5) / 1.2);
}