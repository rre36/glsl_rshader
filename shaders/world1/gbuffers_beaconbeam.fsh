#version 400 compatibility
#include "/lib/util/math.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
in vec3 nrm;

uniform sampler2D tex;

vec4 inputSample;
vec3 normal;
float materialMask = 0.0;

#include "/lib/util/encode.glsl"

struct returnData{
    vec4 scene;
    vec2 lmap;
    float roughness;
    float specular;
    float metalness;
    float materials;
} rdata;

void encodeMatBuffer() {
    float beacon = remap(1.0, 0.92, 0.95);
    materialMask = beacon;
}

void main() {
    inputSample = texture(tex, coord);
    inputSample.rgb *= col.rgb;
    normal = nrm;

    encodeMatBuffer();

    rdata.lmap      = lmap;
    rdata.scene     = inputSample;
    rdata.specular  = 0.0;
    rdata.roughness = 0.9;
    rdata.metalness = 0.0;
    rdata.materials = saturate(materialMask);

    /*DRAWBUFFERS:01234*/
    gl_FragData[0] = makeSceneOutput(rdata.scene);
    gl_FragData[1] = toVec4(normal*0.5+0.5);
    gl_FragData[2] = vec4(lmap, encodeV2(rdata.specular, rdata.roughness), 1.0);
    gl_FragData[3] = vec4(0.25, rdata.materials, rdata.metalness, 1.0);
    gl_FragData[4] = vec4(vec3(0.0), col.a);
}