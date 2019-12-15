#include "/lib/util/math.glsl"

in vec4 col;
in vec2 coord;
in vec2 lmap;
flat in vec3 nrm;

#ifdef isTextured
    uniform sampler2D tex;
#endif

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

    #ifdef isTextured
        rdata.scene     = texture(tex, coord)*col;
    #else
        rdata.scene     = col;
    #endif

    #ifdef isLit
        rdata.lmap      = lmap;
    #else
        rdata.lmap      = lmap;

        if (lmap.x>0.5) rdata.materials = 0.89;
    #endif

    /*DRAWBUFFERS:01234*/
    gl_FragData[0] = makeSceneOutput(rdata.scene);
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(rdata.lmap, encodeV2(rdata.specular, rdata.roughness), 1.0);
    #ifdef isHand
        gl_FragData[3] = vec4(0.5, rdata.materials, rdata.metalness, 1.0);
    #else
        #ifdef isLit
            gl_FragData[3] = vec4(0.25, rdata.materials, rdata.metalness, 1.0);
        #else
            gl_FragData[3] = vec4(0.35, rdata.materials, rdata.metalness, 1.0);
        #endif
    #endif
    gl_FragData[4] = vec4(vec3(0.0), col.a);
}