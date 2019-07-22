#version 400 compatibility
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
flat in vec3 nrm;

flat in vec3 tangent;
flat in vec3 binormal;
flat in mat3 tbn;

flat in float foliage;
flat in float emissive;
flat in int metal;
flat in int subsurface;
flat in int beacon;
flat in int gem;
flat in int lava;
flat in int snow;

uniform sampler2D tex;

#ifdef s_useNormal
    uniform sampler2D normals;
#endif

#ifdef s_usePBR
    uniform sampler2D specular;
#endif

float materialMask = 0.0;
vec3 normal;
float roughness;
float metalness;
float specularity;
float ao;
float emissiveTex;

vec4 inputSample;
vec3 normalSample;
vec4 pbrSample;

struct pbrData{
    float roughness;
    float f0;
    float porosity;
    float emission;
    float sss;
    float ao;
} pbr;

struct returnData{
    vec4 scene;
    vec2 lmap;
    float roughness;
    float f0;
    float metalness;
    float materials;
    float ao;
} rdata;

#include "/lib/util/encode.glsl"

vec3 flattenNormal(vec3 n) {
    const vec3 flatNormal = vec3(0.0, 0.0, 1.0);
    return mix(n, flatNormal, setNormalFlatten);
}

#include "/lib/labPBR.glsl"

void encodeMatBuffer() {
    float fol = remap(foliage, 0.1, 0.5);
    float sss = remap(subsurface, 0.51, 0.70);
    float emi = remap(emissive, 0.71, 0.90);
    float bec = remap(float(beacon), 0.92, 0.95);
    materialMask = fol+emi+sss+bec;
}

void main() {

    inputSample = texture(tex, coord);

    if (inputSample.a<0.15) discard;

    inputSample.rgb *= col.rgb;

    #ifdef s_useNormal
        normalSample = texture(normals, coord).rgb;
    #endif

    #ifdef s_usePBR
        pbrSample = texture(specular, coord);
    #endif

    normal = nrm;
    roughness = 0.9;
    metalness = 0.0;
    ao = 1.0;
    emissiveTex = 0.0;
    specularity = 0.1;

    rdata.ao    = col.a;

    #ifdef s_useNormal
        getLabNormal();
    #endif

    #ifdef s_usePBR
        getLabPbr();

        #ifdef s_useTexAO
            rdata.ao *= ao;
        #endif
    #else
        metalness = float(metal);
        roughness = metal>0.5 ? 0.2 : 1.0;
        specularity = metal>0.5 ? 0.5 : 0.0;
    #endif

    encodeMatBuffer();

    rdata.lmap      = lmap;
    rdata.scene     = inputSample;
    rdata.f0  = specularity;
    rdata.roughness = max(roughness, 0.08);
    rdata.metalness = saturate(metalness);
    rdata.materials = saturate(materialMask);

    /*DRAWBUFFERS:01234*/
    gl_FragData[0] = makeSceneOutput(rdata.scene);
    gl_FragData[1] = toVec4(normal*0.5+0.5);
    gl_FragData[2] = vec4(max(lmap.x, emissiveTex), lmap.y, encodeV2(rdata.f0, rdata.roughness), 1.0);
    gl_FragData[3] = vec4(0.25, rdata.materials, rdata.metalness, 1.0);
    gl_FragData[4] = vec4(vec3(0.0), rdata.ao);
}