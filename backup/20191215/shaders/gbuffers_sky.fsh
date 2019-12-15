#include "/lib/util/math.glsl"

flat in vec3 nrm;

#ifdef noSky 
void main() { 
    /*DRAWBUFFERS:013*/
    gl_FragData[0] = makeSceneOutput(vec3(0.0));
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
}
#else
in vec4 col;
in vec2 coord;
in vec2 lmap;

#ifdef isTextured
    uniform sampler2D tex;
#endif

struct returnData{
    vec4 scene;
} rdata;

void main() { 
    rdata.scene         = vec4(0.0);

    #ifdef isTextured
        rdata.scene     = texture(tex, coord)*col;
    #else
        rdata.scene     = col;
    #endif

    /*DRAWBUFFERS:013*/
    gl_FragData[0] = makeSceneOutput(rdata.scene);
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
}
#endif