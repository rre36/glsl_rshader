const float pi = 3.14159265358979323846;

#define far16 256.0

#define planetRadius 6731000.0

#define diag3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define projMAD(m, v) (diag3(m) * (v) + (m)[3].xyz)
#define viewMAD(m, v) (mat3(m) * (v) + (m)[3].xyz)

#define dotSelf(x) dot(x, x)
#define fnorm(x) x*inversesqrt(dotSelf(x))
#define finv(x) (1.0-x)

#define sstep(x, low, high) smoothstep(low, high, x)
#define saturate(x) clamp(x, 0.0, 1.0)

const float invLog2 = 1.0/log(2.0);

float pow2(float x) {
    return x*x;
}
float pow3(float x) {
    return pow2(x)*x;
}
float pow4(float x) {
    return pow2(pow2(x));
}
float pow5(float x) {
    return pow4(x)*x;
}
float pow6(float x) {
    return pow2(pow3(x));
}
float pow8(float x) {
    return pow2(pow4(x));
}
float pow10(float x) {
    return pow5(x)*pow5(x);
}

vec3 pow2(vec3 x) {
    return x*x;
}

vec3 linCol(vec3 x) {
    return pow(x, vec3(2.2));
}
vec3 gammaCol(vec3 x) {
    return pow(x, vec3(1.0/2.2));
}

vec4 toVec4(vec3 x) {
    return vec4(x, 1.0);
}
vec3 toVec3(vec4 x) {
    return x.xyz/x.w;
}
float sumVec2(vec2 x) {
    return x.x+x.y;
}
float sumVec3(vec3 x) {
    return x.x+x.y+x.z;
}

float saturateF(float x) {
    return clamp(x, 0.0, 1.0);
}
vec3 saturateV3(vec3 x) {
    return clamp(x, 0.0, 1.0);
}

float smoothCubic(float x) {
    return pow2(x) * (3.0-2.0*x);
}

float linStep(float x, float low, float high) {
    float t = saturate((x-low)/(high-low));
    return t;
}

float getLuma(vec3 color) {
	return dot(color,vec3(0.22, 0.687, 0.084));
}

float vec3avg(vec3 x) {
    return (x.r+x.g+x.b)/3.0;
}

float flatten(float x, float alpha) {
    return x*alpha+(1.0-alpha);
}

float coordDist(vec2 x) {
    return max(abs(x.x-0.5), abs(x.y-0.5))*2.0;
}

float getFresnel(vec3 n, vec3 v, int exp, bool invert) {
    float fresnel = 0.0;
    if (invert == false) fresnel = dot(normalize(n), v)*0.5+0.5;
    if (invert == true) fresnel = 1.0-(dot(normalize(n), v)*0.5+0.5);
    if (exp == 1) return fresnel;
    if (exp == 2) return pow2(fresnel);
    if (exp == 3) return pow3(fresnel);
    if (exp == 4) return pow4(fresnel);
    if (exp == 5) return pow5(fresnel);
    if (exp == 6) return pow6(fresnel);
    if (exp == 0 || exp > 6) return 1.0;
}

vec2 rsi(vec3 position, vec3 direction, float radius) {   //from robobo1221
	float PoD = dot(position, direction);
	float radiusSquared = radius * radius;

	float delta = PoD * PoD + radiusSquared - dot(position, position);
	if (delta < 0.0) return vec2(-1.0);
	      delta = sqrt(delta);
	return -PoD + vec2(-delta, delta);
}

float bLighten(float x, float blend) {
	return max(x, blend);
}
vec3 bLighten(vec3 x, vec3 blend) {
	return vec3(bLighten(x.r, blend.r), bLighten(x.g, blend.g), bLighten(x.b, blend.b));
}

float bScreen(float x, float blend) {
	return 1.0-((1.0-x)*(1.0-x));
}
vec3 bScreen(vec3 x, vec3 blend) {
	return vec3(bScreen(x.r,blend.r),bScreen(x.g,blend.g),bScreen(x.b,blend.b));
}
vec3 bScreen(vec3 x, vec3 blend, float alpha) {
	return (bScreen(x, blend) * alpha + x * (1.0 - alpha));
}

vec3 colorSat(vec3 x, float alpha) {
    return mix(vec3(getLuma(x)), x, alpha);
}
vec3 planetCurvePosition(in vec3 x, const float alpha, const float scale) {
    return vec3(x.x, mix(x.y, length(x + vec3(0.0, planetRadius*scale, 0.0))-planetRadius*scale, alpha), x.z);
}
vec3 planetCurvePosition(in vec3 x, const float alpha) {
    return vec3(x.x, mix(x.y, length(x + vec3(0.0, planetRadius, 0.0))-planetRadius, alpha), x.z);
}
vec3 planetCurvePosition(in vec3 x) {
    return vec3(x.x, length(x + vec3(0.0, planetRadius, 0.0))-planetRadius, x.z);
}

vec4 makeSceneOutput(in vec3 returnCol) {
    #ifdef MC_GL_RENDERER_GEFORCE
        vec3 temp   = clamp(returnCol, 1.0/65530.0, 65535.0);
    #else
        vec3 temp   = clamp(returnCol, 0.0, 65535.0);
    #endif

    return toVec4(temp);
}
vec4 makeSceneOutput(in vec4 returnCol) {
    #ifdef MC_GL_RENDERER_GEFORCE
        vec3 temp   = clamp(returnCol.xyz, 1.0/65530.0, 65535.0);
    #else
        vec3 temp   = clamp(returnCol.xyz, 0.0, 65535.0);
    #endif

    return vec4(temp, max(returnCol.a, 0.0));
}