#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

#define taaClamp(x) clamp(x, 0.0, 65535.0)

/* ------ buffer formats ------ */

const int colortex7Format   = RGBA16F;

const bool colortex7Clear   = false;

const bool colortex0MipmapEnabled = true;
const bool colortex7MipmapEnabled = false;


/* ------ uniforms ------ */

uniform sampler2D colortex0;
uniform sampler2D colortex7;

uniform sampler2D depthtex1;

uniform int frameCounter;

uniform float frameTime;
uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;


/* ------ inputs from vertex stage ------ */

in vec2 coord;

vec3 returnCol;
vec3 returnTemporal;


#include "/lib/post/taa.glsl"

float getImageLuma(sampler2D tex) {
    vec3 sample1 = textureLod(colortex0, vec2(0.5), ceil(log2(max(viewHeight, viewWidth)))).rgb;
    vec3 sample2 = textureLod(colortex0, vec2(0.5), ceil(log2(max(viewHeight, viewWidth)))/1.5).rgb;

    return getLuma((sample1*0.9+sample2*0.1));
}

void temporalExposure(out float expResult) {
    float expCurrent    = texture(colortex7, coord).a;
    float expTarget     = taaClamp(getImageLuma(colortex0));
        expTarget       = clamp(expTarget, expMinimum, expMaximum);
        expResult       = mix(expCurrent, expTarget, 0.025*(frameTime/0.033));
}


void main() {
    returnCol       = textureLod(colortex0, coord, 0).rgb;
    float depth     = textureLod(depthtex1, coord, 0).x;

    float expResult = 1.0;

    #if expMethod==0
        temporalExposure(expResult);
    #endif

    #ifdef temporalAA
        applyTAA(depth);
    #else
        returnTemporal  = returnCol;
    #endif

    /*DRAWBUFFERS:07*/
    gl_FragData[0]  = makeSceneOutput(returnTemporal);
    gl_FragData[1]  = vec4(returnTemporal, expResult);
}