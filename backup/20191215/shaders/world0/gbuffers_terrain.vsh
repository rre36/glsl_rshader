#version 400 compatibility
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

out vec4 col;
out vec2 coord;
out vec2 lmap;
out vec3 wpos;
flat out vec3 upVec;
flat out vec3 nrm;

flat out vec3 tangent;
flat out vec3 binormal;
flat out int beacon;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform vec3 upPosition;

uniform sampler2D noisetex;

vec4 position;

attribute vec4 at_tangent;

#include "/lib/util/taaJitter.glsl"
#include "/lib/terrain/blocks.glsl"
#include "/lib/terrain/transform.glsl"
#include "/lib/terrain/wind.glsl"

void main() {
    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;

    if (mc_Entity.x == 301.0) beacon = 1;
    else beacon = 0;

    idSetup();
    matSetup();

    position        = ftransform();

    #ifdef setWindEffect
		windOcclusion   = linStep(lmap.y, 0.45, 0.8)*0.9+0.1;
	#endif

    unpackPos();
    #ifdef setWindEffect
        applyWind();
    #endif
    wpos = position.xyz;
    repackPos();

    #ifdef temporalAA
        position.xy = taaJitter(position.xy, position.w);
    #endif
    gl_Position     = position;
    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
    upVec           = normalize(upPosition);

    tangent = vec3(0.0);
	binormal = vec3(0.0);
    
	tangent = normalize(gl_NormalMatrix * at_tangent.xyz);
	binormal = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
}