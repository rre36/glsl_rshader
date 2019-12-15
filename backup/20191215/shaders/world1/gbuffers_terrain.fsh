#version 400 compatibility
#include "/lib/util/math.glsl"
#include "/lib/global.glsl"
#include "/lib/end/opt.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
flat in vec3 nrm;

flat in vec3 tangent;
flat in vec3 binormal;

flat in float foliage;
flat in float emissive;
flat in int metal;
flat in int subsurface;
flat in int beacon;

uniform sampler2D tex;

#ifdef setTexturePBR
    uniform sampler2D specular;
#endif

#ifdef setTextureNormal
    uniform sampler2D normals;
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

struct returnData{
    vec4 scene;
    vec2 lmap;
    float roughness;
    float specular;
    float metalness;
    float materials;
} rdata;

#include "/lib/util/encode.glsl"

vec3 flattenNormal(vec3 n) {
    const vec3 flatNormal = vec3(0.0, 0.0, 1.0);
    return mix(n, flatNormal, setNormalFlatten);
}

#ifdef setTextureNormal
void textureNormals() {
    vec3 textureNormal  = normalSample;
        textureNormal.xy = textureNormal.xy*2.0-1.0;
        
        #if setTexturePBRmode==4
            textureNormal = normalize(textureNormal);
        #endif

        #ifdef setNormalFix
            textureNormal.xy *= 1.0-textureNormal.z;
        #endif

        textureNormal   = normalize(textureNormal);
        textureNormal   = flattenNormal(textureNormal);

    mat3 tbnMatrix = mat3(tangent.x, binormal.x, nrm.x,
				tangent.y, binormal.y, nrm.y,
				tangent.z, binormal.z, nrm.z);

    normal  = textureNormal*tbnMatrix;
}
#endif

void encodeMatBuffer() {
    float fol = remap(foliage, 0.1, 0.5);
    float sss = remap(subsurface, 0.51, 0.70);
    float emi = remap(emissive, 0.71, 0.90);
    float bec = remap(float(beacon), 0.92, 0.95);
    materialMask = fol+emi+sss+bec;
}

void main() {

    inputSample = texture(tex, coord);
    inputSample.rgb *= col.rgb;

    #ifdef setTextureNormal
        normalSample = texture(normals, coord).rgb;
    #endif

    normal = nrm;
    roughness = 0.9;
    metalness = 0.0;
    ao = 1.0;
    emissiveTex = 0.0;
    specularity = 0.1;

    #ifdef setTextureNormal
        textureNormals();
    #endif

    metalness = float(metal);
    roughness = metal>0.5 ? 0.2 : 1.0;
    specularity = metal>0.5 ? 0.5 : 0.0;

    encodeMatBuffer();

    inputSample.a *= ao;

    rdata.lmap      = lmap;
    rdata.scene     = inputSample;
    rdata.specular  = specularity;
    rdata.roughness = max(roughness, 0.08);
    rdata.metalness = saturate(metalness);
    rdata.materials = saturate(materialMask);

    /*DRAWBUFFERS:01234*/
    gl_FragData[0] = makeSceneOutput(rdata.scene);
    gl_FragData[1] = toVec4(normal*0.5+0.5);
    gl_FragData[2] = vec4(max(lmap.x, emissiveTex), lmap.y, encodeV2(rdata.specular, rdata.roughness), 1.0);
    gl_FragData[3] = vec4(0.25, rdata.materials, rdata.metalness, 1.0);
    gl_FragData[4] = vec4(vec3(0.0), col.a);
}