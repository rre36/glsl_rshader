uniform float frameTimeCounter;
uniform int worldTime;
uniform int worldDay;

uniform float rainStrength;
uniform float wetness;
const float wetnessHalflife = 300.0;
const float drynessHalflife = 100.0;

float animTick = frameTimeCounter*pi;

float windOcclusion = 1.0;

vec2 windVec2(float x) {
    vec2 wind1 = vec2(1.0, 0.0);
    vec2 wind2 = vec2(0.0, 1.0);

    vec2 dir = vec2(1.0-abs(clamp(x, -1.0, 1.0)), clamp(x, -1.0, 1.0));
    
    return -normalize(vec3(dir, length(dir))).xy;
}
vec3 windVec3(float x) {
    vec3 wind1 = vec3(-1.0, 0.3, 0.0);
    vec3 wind2 = vec3(0.0, -0.8, -1.0);
    return normalize(mix(wind1, wind2, x));
}

float windMacroGust(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xz *= -windVec2(dir);
    float loc   = pos.x+pos.z;
    float tick  = animTick*speed;
    float s1    = sin(tick+loc)*0.7+0.2;
    float c1    = cos(tick*0.654+loc)*0.7+0.2;
    return (s1+c1)*strength;
}
float windWave(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xz *= -windVec2(dir);
    float loc   = pos.x+pos.z;
    float tick  = animTick*speed;
    float s1    = sin(animTick+loc)*0.68+0.2;
    return s1*strength;
}
float windMicroGust(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xz *= -windVec2(dir);
    float loc   = pos.x+pos.z;
    float tick  = animTick*speed;
    float s1    = sin(tick*3.5+loc)*0.5+0.5;
    float s2    = sin(tick*0.5+loc)*0.66+0.34;
        s2      = max(s2*1.2-0.2, 0.0);
    float c1    = cos(tick*0.7+loc)*0.7+0.23;
        c1      = max(c1*1.3-0.3, 0.0);
    return mix(s2, c1, s1)*strength;
}

void windEffect(inout vec4 pos, in float speed, in float amp, in float size) {
    vec3 windPos    = pos.xyz*size;
    float dir       = 0.1;

    vec2 macroWind  = vec2(0.0);
        macroWind  += vec2(windMacroGust(windPos*0.3, speed*0.53, 0.96, dir+0.0))*windVec2(dir+0.0);
        macroWind  += vec2(windWave(windPos*0.64, speed*0.42, 0.87, dir+0.29))*windVec2(dir+0.29);
        macroWind  *= 1.0-wetness*0.6;

    vec2 microWind  = vec2(0.0);
        microWind  += vec2(windMicroGust(windPos*0.8, speed*0.6, 0.78, dir+0.22))*windVec2(dir+0.22);
        microWind  += vec2(windMicroGust(windPos*1.0, speed*0.72, 0.63, dir-0.05))*windVec2(dir-0.05);

    pos.xz += (macroWind*0.8+microWind)*amp*windOcclusion;
}

float BwindMacroGust(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xyz *= -windVec3(dir);
    float loc   = sumVec3(pos);
    float tick  = animTick*speed;
    float s1    = sin(tick+loc)*0.7+0.2;
    float c1    = cos(tick*0.654+loc)*0.7+0.2;
    return (s1+c1)*strength;
}
float BwindWave(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xyz *= -windVec3(dir);
    float loc   = sumVec3(pos);
    float tick  = animTick*speed;
    float s1    = sin(animTick+loc)*0.68+0.2;
    return s1*strength;
}
float BwindMicroGust(in vec3 pos, in float speed, in float strength, in float dir) {
    pos.xyz *= -windVec3(dir);
    float loc   = sumVec3(pos);
    float tick  = animTick*speed;
    float s1    = sin(tick*3.5+loc)*0.5+0.5;
    float s2    = sin(tick*0.5+loc)*0.66+0.34;
        s2      = max(s2*1.2-0.2, 0.0);
    float c1    = cos(tick*0.7+loc)*0.7+0.23;
        c1      = max(c1*1.3-0.3, 0.0);
    return mix(s2, c1, s1)*strength;
}


void BwindEffect(inout vec4 pos, in float speed, in float amp, in float size) {
    vec3 windPos    = pos.xyz*size;
    float dir       = 0.1;

    vec3 macroWind  = vec3(0.0);
        macroWind  += vec3(windMacroGust(windPos*0.3, speed*0.53, 0.96, dir+0.0))*windVec3(dir+0.0);
        macroWind  += vec3(windWave(windPos*0.64, speed*0.42, 0.87, dir+0.29))*windVec3(dir+0.29);
        macroWind  *= 1.0-wetness*0.6;

    vec3 microWind  = vec3(0.0);
        microWind  += vec3(windMicroGust(windPos*0.8, speed*0.6, 0.78, dir+0.22))*windVec3(dir+0.22);
        microWind  += vec3(windMicroGust(windPos*1.0, speed*0.72, 0.63, dir-0.05))*windVec3(dir-0.05);

    pos.xyz += (macroWind+microWind+0.35)*amp*windOcclusion;
}

void applyWind() {
    if (blockWindGround && isTopVertex) {
        windEffect(position, 0.7, 0.18, 1.0);
    }
    if (blockWindDoubleLow && isTopVertex) {
        windEffect(position, 0.7, 0.18/2, 1.0);
    }
    if (blockWindDoubleHigh) {
        windEffect(position, 0.7, isTopVertex ? 0.18 : 0.18/2, 1.0);
    }
    if (blockWindFree) {
        BwindEffect(position, 0.7, 0.028, 1.7);
    }
}