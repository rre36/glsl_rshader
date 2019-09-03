#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

out vec4 col;
out vec2 coord;
out vec2 lmap;
out vec3 wpos;
out float vertexDist;
out vec3 vertexViewVec;

flat out vec3 nrm;
flat out vec3 tangent;
flat out vec3 binormal;

flat out int water;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;

uniform sampler2D noisetex;

flat out vec3 sunVector;
flat out vec3 moonVector;
flat out vec3 lightVector;
flat out vec3 upVector;

vec4 position;

#include "/lib/util/taaJitter.glsl"
#include "/lib/terrain/transform.glsl"
#include "/lib/util/time.glsl"
#include "/lib/nature/nvars.glsl"

void main() {
    daytime();
    nature();

    position     = ftransform();

    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) water = 1;
    else water = 0;

    unpackPos();
    wpos = position.xyz;
    repackPos();

    #ifdef temporalAA
        position.xy  = taaJitter(position.xy, position.w);
    #endif

    gl_Position     = position;
    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
	tangent         = normalize(gl_NormalMatrix * at_tangent.xyz);
	binormal        = normalize(gl_NormalMatrix * cross(at_tangent.xyz, gl_Normal.xyz) * at_tangent.w);
    sunVector       = normalize(sunPosition);
    moonVector      = normalize(moonPosition);
    lightVector     = normalize(shadowLightPosition);
    upVector        = normalize(upPosition);

    mat3 tbnMatrix = mat3(tangent.x, binormal.x, nrm.x,
				tangent.y, binormal.y, nrm.y,
				tangent.z, binormal.z, nrm.z);
                
    vertexDist = length(gl_ModelViewMatrix * gl_Vertex);
    vertexViewVec = (gl_ModelViewMatrix*gl_Vertex).xyz;
    vertexViewVec = tbnMatrix * vertexViewVec;
}