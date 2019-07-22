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

    rdata.scene     = texture(tex, coord)*col;


    /*DRAWBUFFERS:0*/
    gl_FragData[0] = makeSceneOutput(rdata.scene);
}