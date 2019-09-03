#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float shadowBias = 0.85;

out vec4 col;
out vec2 coord;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform sampler2D noisetex;

vec4 position;

#include "/lib/terrain/blocks.glsl"
#include "/lib/terrain/transform.glsl"
#include "/lib/terrain/wind.glsl"
#include "/lib/shadow/warp.glsl"

void main() {

    idSetup();
    matSetup();

    position = gl_ProjectionMatrix*gl_ModelViewMatrix*gl_Vertex;

    unpackShadow();
    #ifdef setWindEffect
        applyWind();
    #endif
    repackShadow();

    warpShadowmap(position.xy);

    gl_Position = position;
    gl_Position.z *= 0.2;
    coord       = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    col         = gl_Color;
}