#version 400 compatibility
#include "/lib/util/math.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
flat in vec3 nrm;

uniform sampler2D tex;

#include "/lib/util/encode.glsl"

struct returnData{
    vec4 scene;
    vec2 lmap;
    float roughness;
    float specular;
    float metalness;
    float materials;
} rdata;

void main() { 
    rdata.scene         = vec4(0.0);
    rdata.lmap          = vec2(0.0);
    rdata.roughness     = 1.0;
    rdata.specular      = 0.0;
    rdata.metalness     = 0.0;
    rdata.materials     = 0.0;

    rdata.scene     = texture(tex, coord*2.0)*col;
    rdata.scene.rgb = colorSat(rdata.scene.rgb, 0.15)*1.5;
    rdata.scene.a  *= 0.6;

    rdata.lmap      = lmap;

    /*DRAWBUFFERS:01234*/
    gl_FragData[0] = makeSceneOutput(rdata.scene);
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(rdata.lmap, encodeV2(rdata.specular, rdata.roughness), 1.0);
    gl_FragData[3] = vec4(0.85, rdata.materials, rdata.metalness, 1.0);
    gl_FragData[4] = vec4(vec3(0.0), 1.0);
}