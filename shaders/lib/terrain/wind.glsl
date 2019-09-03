uniform float frameTimeCounter;
uniform int worldTime;
uniform int worldDay;

uniform float rainStrength;
uniform float wetness;
const float wetnessHalflife = 300.0;
const float drynessHalflife = 100.0;

float animTick = frameTimeCounter*pi;

float windOcclusion = 1.0;

const float windRotation = 0.3;

#include "/lib/util/rotateCoord.glsl"

float getNoiseWind2D(in vec3 pos, in float size, in vec3 offset) {
    pos /= 1024;
    pos *= size;
    pos += offset;

    return texture(noisetex, pos.xz).x*2.0-1.0;
}

float getNoiseWind3D(in vec3 pos, in float size, in vec3 offset) {
    pos /= 1024;
    pos *= size;
    pos += offset;

    vec3 i          = floor(pos);
    vec3 f          = fract(pos);

    vec2 p1         = (i.xy+i.z*vec2(17.0)+f.xy);
    vec2 p2         = (i.xy+(i.z+1.f)*vec2(17.0))+f.xy;
    vec2 c1         = (p1+0.5);
    vec2 c2         = (p2+0.5);
    float r1        = texture(noisetex, c1).r;
    float r2        = texture(noisetex, c2).r;
    return mix(r1, r2, f.z)*2-1;
}

float windMacroGust(in vec3 pos, in float speed) {
    float loc   = pos.x+pos.z;
    float tick  = animTick*speed;
    float s1    = sin(tick+loc)*0.7+0.2;
    float c1    = cos(tick*0.654+loc)*0.7+0.2;
    return (s1+c1);
}
float windWave(in vec3 pos, in float speed) {
    float loc   = length(pos.xz);
    float tick  = animTick*speed;
    float s1    = sin(tick+loc)*0.68+0.2;
    return s1;
}

void windEffect(inout vec3 pos, in float speed, in float amp, in float size) {
    vec3 windpos    = pos.xyz*size;
        windpos.xz  = rotateCoord(windpos.xy, windRotation*pi);

    vec2 macroWind  = vec2(0.0);
        macroWind  += windMacroGust(windpos, 1.0)*vec2(1.0, 0.1);
        macroWind  += windWave(windpos, 1.2)*vec2(1.0, -0.1);

    vec2 microWind  = vec2(0.0);
        microWind  += getNoiseWind3D(windpos, 2.8, vec3(animTick*0.0006)*vec3(1.0, 0.5, 0.8))*vec2(1.0, 0.7);
        microWind  -= getNoiseWind3D(windpos, 3.9, vec3(animTick*0.00052)*vec3(0.7, 0.7, 1.0))*0.8*vec2(1.0, -0.5);
        microWind  += getNoiseWind3D(windpos, 4.3, vec3(animTick*0.00045)*vec3(1.0, 0.8, 0.9))*0.5*vec2(1.0, 0.8);
        microWind.x += 0.2;
        microWind  *= max(windWave(windpos*0.05, 0.1)+0.6, 0.0)*0.5+0.2+rainStrength*0.2;

    pos.xz         += (macroWind*0.33+microWind*1.1)*vec2(-1, 1)*0.75*amp*windOcclusion;
}

void BwindEffect(inout vec3 pos, in float speed, in float amp, in float size) {
    vec3 windpos    = pos.xyz*size;
        windpos.xz  = rotateCoord(windpos.xy, windRotation*pi);

    vec2 macroWind  = vec2(0.0);
        macroWind  += windMacroGust(windpos, 1.0)*vec2(1.0, 0.1);
        macroWind  += windWave(windpos, 1.2)*vec2(1.0, -0.1);

    vec3 microWind  = vec3(0.0);
        microWind  += getNoiseWind3D(windpos, 3.8, vec3(animTick*0.0006)*vec3(1.0, 0.5, 0.8))*vec3(1.0, 1.0, 0.7);
        microWind  += getNoiseWind3D(windpos, 5.3, vec3(animTick*0.00045)*vec3(1.0, 0.8, 0.9))*0.5*vec3(1.0, 1.0, 0.8);
        microWind  *= max(windWave(windpos*0.05, 0.1)+0.6, 0.0)*0.5+0.2+rainStrength*0.2;

    pos.xz         += (macroWind*0.33+microWind.xz*1.1)*vec2(-1, 1)*0.75*amp*windOcclusion;
    pos.y          += (microWind.y*1.1)*0.75*amp*windOcclusion;
}

void applyWind() {
    if (blockWindGround && isTopVertex) {
        windEffect(position.xyz, 0.7, 0.18, 1.0);
    }
    if (blockWindDoubleLow && isTopVertex) {
        windEffect(position.xyz, 0.7, 0.18/2, 1.0);
    }
    if (blockWindDoubleHigh) {
        windEffect(position.xyz, 0.7, isTopVertex ? 0.18 : 0.18/2, 1.0);
    }
    if (blockWindFree) {
        BwindEffect(position.xyz, 0.7, 0.038, 1.7);
    }
}