#include "/lib/util/math.glsl"

out vec2 coord;

#ifdef doVectors
    uniform vec3 upPosition;

    flat out vec3 upVector;
    uniform mat4 gbufferModelView;
#endif

#ifdef doNvars
    #include "/lib/end/nvars.glsl"
#endif

void main() {
    #ifdef doNvars
        nature();
    #endif

    gl_Position     = ftransform();
    coord           = gl_MultiTexCoord0.xy;

    #ifdef doVectors
        upVector        = normalize(upPosition);
    #endif
}