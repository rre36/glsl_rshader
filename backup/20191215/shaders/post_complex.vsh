#include "/lib/util/math.glsl"

out vec2 coord;

#ifdef doVectors
    uniform vec3 sunPosition;
    uniform vec3 moonPosition;
    uniform vec3 upPosition;
    uniform vec3 shadowLightPosition;

    flat out vec3 sunVector;
    flat out vec3 moonVector;
    flat out vec3 lightVector;
    flat out vec3 upVector;
#endif

#include "/lib/util/time.glsl"

#ifdef doNvars
    #include "/lib/nature/nvars.glsl"
#endif

void main() {
    daytime();

    #ifdef doNvars
        nature();
    #endif

    gl_Position     = ftransform();
    coord           = gl_MultiTexCoord0.xy;

    #ifdef doVectors
        sunVector       = normalize(sunPosition);
        moonVector      = normalize(moonPosition);
        lightVector     = normalize(shadowLightPosition);
        upVector        = normalize(upPosition);
    #endif
}