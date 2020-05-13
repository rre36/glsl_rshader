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



#define viewMAD(m, v) (mat3(m) * (v) + (m)[3].xyz)
#define diag3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define diag4(mat) vec4(diag3(mat), (mat)[2].w)
#define projMAD(m, v) (diag3(m) * (v) + (m)[3].xyz)

#define csaturate(x) clamp(x, 0.0, 1.0)
#define crcp(x) (1.0 / x)

#define sstep(x, low, high) smoothstep(low, high, x)
#define stex(x) texture(x, coord)
#define stexLod(x, lod) textureLod(x, coord, lod)
#define landMask(x) (x < 1.0)
#define icubeSmooth(x) (x * x) * (3.0 - 2.0 * x)

#define expf(x) exp2((x) * rlog2)
#define log10(x) (log(x) * rcp(log(10.0)))

#define isnan3(a) (isnan(a.x) || isnan(a.y) || isnan(a.z))
#define isinf3(a) (isinf(a.x) || isinf(a.y) || isinf(a.z))

#define isnan4(a) (isnan(a.x) || isnan(a.y) || isnan(a.z) || isnan(a.w))
#define isinf4(a) (isinf(a.x) || isinf(a.y) || isinf(a.z) || isinf(a.w))

#define cpow2(x) (x * x)

//#define max3f(x, y, z) max(x, max(y, z))

//#define max3(x) max(x.x, max(x.y, x.z))