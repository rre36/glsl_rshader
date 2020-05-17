#version 400 compatibility

/*
====================================================================================================

    Copyright (C) 2020 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.github.io/license/

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/

#include "/lib/common.glsl"

in vec2 coord;

flat in mat3x3 lightColor;

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D colortex3;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform int isEyeInWater;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

vec3 decode3x8(float a){
    int bf = int(a*65535.);
    return vec3(bf%32, (bf>>5)%64, bf>>11) / vec3(31,63,31);
}

vec3 blend_translucencies(vec3 scenecol, vec4 translucents, vec3 albedo) {
    vec3 color  = scenecol;
        color  *= mix(vec3(1.0), albedo, translucents.a);
        color   = mix(color, translucents.rgb, translucents.a);

    return color;
}

vec3 screen_viewspace(vec3 screenpos, mat4 projInv) {
    screenpos   = screenpos*2.0-1.0;

    //screenpos.xy -= taaOffset;

    vec3 viewpos    = vec3(vec2(projInv[0].x, projInv[1].y)*screenpos.xy + projInv[3].xy, projInv[3].z);
        viewpos    /= projInv[2].w*screenpos.z + projInv[3].w;
    
    return viewpos;
}

vec3 screen_viewspace(vec3 screenpos) {
    return screen_viewspace(screenpos, gbufferProjectionInverse);
}

vec3 view_scenespace(vec3 viewpos, mat4 mvInv) {
    return viewMAD(mvInv, viewpos);
}

vec3 view_scenespace(vec3 viewpos) {
    return view_scenespace(viewpos, gbufferModelViewInverse);
}

int decodeMatID16(float x) {
    return int(x*65535.0);
}

vec3 simple_fog(vec3 scenecolor, float d, vec3 color) {
    float dist      = max(0.0, d-32.0);
    float density   = 1.0-exp(-dist*1e-3);

    return mix(scenecolor, vec3(0.0), density);
}
vec3 water_fog(vec3 scenecolor, float d, vec3 color) {
    float dist      = max(0.0, d);
    float density   = dist*6.5e-1;
    vec3 scatter   = 1.0-exp(-min(density*0.8, 64e-1)*vec3(0.02, 0.24, 1.0));
    vec3 transmittance = exp(-density*vec3(1.0, 0.28, 0.06)*1.2);

    return scenecolor*transmittance + color*scatter*0.3;
}

void main() {
    vec4 scenecol   = stex(colortex0);  //that macro certainly makes it neater
    //vec4 tex1       = stex(colortex1);
    vec4 tex2       = stex(colortex2);
    vec4 tex3       = stex(colortex3);

    int mat_id      = decodeMatID16(tex2.x);

    float scenedepth0 = stex(depthtex0).x;
    vec3 viewpos0     = screen_viewspace(vec3(coord, scenedepth0));
    vec3 spos0        = view_scenespace(viewpos0);

    float scenedepth1 = stex(depthtex1).x;
    vec3 viewpos1     = screen_viewspace(vec3(coord, scenedepth1));
    vec3 spos1        = view_scenespace(viewpos1);

    bool translucent = (scenedepth0<scenedepth1);

    bool water      = mat_id == 102;

    vec3 translucent_albedo = sqr(decode3x8(tex2.g));
    
    float dist0     = distance(spos0, gbufferModelViewInverse[3].xyz);
    float dist1     = distance(spos1, gbufferModelViewInverse[3].xyz);

    if (translucent && isEyeInWater==0){
        if (water) scenecol.rgb = water_fog(scenecol.rgb, dist1-dist0, lightColor[1]);
        else if (landMask(scenedepth1)) scenecol.rgb = simple_fog(scenecol.rgb, dist1-dist0, lightColor[1]);
    }

    if (landMask(scenedepth1) && isEyeInWater==1 && translucent) scenecol.rgb = simple_fog(scenecol.rgb, dist1-dist0, lightColor[1]);

    scenecol.rgb    = blend_translucencies(scenecol.rgb, tex3, translucent_albedo);

    if (landMask(scenedepth0) && isEyeInWater==0) scenecol.rgb = simple_fog(scenecol.rgb, dist0, lightColor[1]);

    if (isEyeInWater==1) scenecol.rgb = water_fog(scenecol.rgb, dist0, lightColor[1]);

    if (mat_id == 3) {
        if (landMask(scenedepth0)) scenecol.rgb = scenecol.rgb*0.6 + vec3(0.5)*v3avg(scenecol.rgb);
        else scenecol.rgb = scenecol.rgb*0.7 + vec3(0.8)*v3avg(scenecol.rgb);
    }

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
}