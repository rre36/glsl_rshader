#version 400 compatibility

#include "/lib/buffer.glsl"

/* ------ buffer formats ------ */

const int colortex0Format   = RGB16F;
const int colortex1Format   = RGB16F;
const int colortex2Format   = RGB16;
const int colortex3Format   = RGBA16;
const int colortex4Format   = RGBA16F;
const int colortex5Format   = RG16F;
const int colortex6Format   = RGBA16;


/* ------ internal parameters ------ */

const float sunPathRotation = -12.5;

const float wetnessHalflife = 300.0;
const float drynessHalflife = 100.0;

#include "shadow/singlepass.glsl" 