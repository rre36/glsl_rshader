#version 400 compatibility
#include "/lib/util/math.glsl"

out vec4 col;
out vec2 coord;
out vec2 lmap;
out vec3 nrm;

out vec2 beamPos;
out vec3 wPos;
out vec2 relPos;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec4 position;

#include "/lib/util/taaJitter.glsl"

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

void unpackPos() {
    position = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
    position.xyz += cameraPosition.xyz;
}

void repackPos() {
    position    = gbufferModelView * vec4(position.xyz, 0.0);
    position    = gl_ProjectionMatrix * vec4(position.xyz, 1.0);
}

void main() {
vec3 viewPosition = cameraPosition + gbufferModelViewInverse[3].xyz;

    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;

    position        = gl_ModelViewMatrix * gl_Vertex;
    position        = gbufferModelViewInverse * vec4(position.xyz, 0.0);
    beamPos         = floor(position.xz + viewPosition.xz) - viewPosition.xz + 0.5;
    vec2 relPosition = position.xz-beamPos;
    relPos = relPosition;

    if (dot(relPosition, relPosition) > 0.0625) {
        gl_Position = vec4(100.0);
        return;
    }

    position.xz += relPosition*0.5;
    wPos = position.xyz;

    repackPos();

    #ifdef temporalAA
        position.xy = taaJitter(position.xy, position.w);
    #endif
    gl_Position     = position;
    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
}