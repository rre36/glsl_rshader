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
#include "/lib/util/encoders.glsl"

in vec2 coord;

flat in float light_flip;

flat in mat4x3 lightColor;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform int isEyeInWater;

uniform float eyeAltitude;
uniform float far;
uniform float sunAngle;

uniform vec2 taaOffset;
uniform vec2 pixelSize, viewSize;

uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 lightvec, lightvecView;
uniform vec3 sunvec;

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

#include "/lib/util/transforms.glsl"

int decodeMatID16(float x) {
    return int(x*65535.0);
}

vec3 simple_fog(vec3 scenecolor, float d, vec3 color) {
    float dist      = max(0.0, d - 16.0);
    float density   = 1.0-exp(-dist*1.3e-3);
    float edgeFade  = (sstep(d, far * 0.6, far * 0.99));
        density     = mix(density, 1.0, edgeFade);

    return mix(scenecolor, color, density);
}
vec3 water_fog(vec3 scenecolor, float d, vec3 color) {
    float dist      = max(0.0, d);
    float density   = dist*6.5e-1;

    const vec3 absorptionCoeff  = vec3(1.0, 0.4, 0.21);
    const vec3 scatterCoeff     = vec3(0.04, 0.1, 0.6) * 0.3;

    vec3 scatter    = 1.0-exp(-density * scatterCoeff);
        scatter    *= max(expf(-absorptionCoeff * density), expf(-absorptionCoeff * pi));

    vec3 transmittance = exp(-density * absorptionCoeff);

    return scenecolor*transmittance + scatter * color * rcp(pi);
}

#include "/lib/atmos/project.glsl"
#include "/lib/util/bicubic.glsl"
#include "/lib/atmos/phase.glsl"

vec3 apply_clouds(mat2x4 data, vec3 scenecol, vec3 skycol) {
    scenecol    = mix(skycol, scenecol, data[0].a);
    return mix(scenecol, scenecol * data[0].a + data[0].rgb, data[1].rgb);
}
vec3 apply_clouds(mat2x4 data, vec3 scenecol) {
    return mix(scenecol, scenecol * data[0].a + data[0].rgb, data[1].rgb);
}

const float vcloud_maxalt   = vcloud_alt + vcloud_depth;

void main() {
    vec4 scenecol   = stex(colortex0);  //that macro certainly makes it neater
    //vec4 tex1       = stex(colortex1);
    vec4 tex2       = stex(colortex2);
    vec4 tex3       = stex(colortex3);

        vec4 tex1       = stex(colortex1);
        vec2 scenelmap  = decode2x8(tex1.z);
        vec3 scenenormal = decodeNormal(tex1.xy);
    
    //~4fps for the whole part below
    
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

    float cave_fix  = linStep(eyeBrightnessSmooth.y/240.0, 0.1, 0.9);

    float vdotl     = dot(normalize(viewpos1), lightvecView);

    vec3 fogcol     = (sunAngle<0.5 ? lightColor[0] : lightColor[3]) * light_flip * hg_mie(vdotl, 0.68) * sqr(cave_fix);
        fogcol     *= mix(0.33, 1.0, sqrt(abs(lightvec.y)));
        fogcol     += lightColor[1] * cave_fix * rcp(pi);

    vec3 skycol     = textureBicubic(colortex5, projectSky(normalize(spos1))).rgb;

    #ifdef vcloud_enabled
        const float cLOD    = sqrt(CLOUD_RENDER_LOD);
        vec2 cloudcoord = (coord)*rcp(cLOD)+vec2(1.0-rcp(cLOD), 0.0);

        mat2x4 cloud_data   = mat2x4(texture(colortex6, cloudcoord), texture(colortex5, cloudcoord));

        bool is_cloud   = ((spos1.y + eyeAltitude) > vcloud_alt && eyeAltitude < vcloud_alt) ||
                        ((spos1.y + eyeAltitude) < vcloud_maxalt && eyeAltitude > vcloud_maxalt);
            is_cloud    = is_cloud || (eyeAltitude > vcloud_alt && eyeAltitude < vcloud_maxalt);

        if (!landMask(scenedepth1)) {
            scenecol.rgb = apply_clouds(cloud_data, scenecol.rgb, skycol);
        } else if (is_cloud) {
            scenecol.rgb = apply_clouds(cloud_data, scenecol.rgb);
        }
    #endif

    if (translucent && isEyeInWater==0){
        if (water) scenecol.rgb = water_fog(scenecol.rgb, dist1-dist0, fogcol);
        else if (landMask(scenedepth1)) scenecol.rgb = simple_fog(scenecol.rgb, dist1-dist0, skycol*cave_fix);
    }

    if (landMask(scenedepth1) && isEyeInWater==1 && translucent) scenecol.rgb = simple_fog(scenecol.rgb, dist1-dist0, skycol*cave_fix);

    scenecol.rgb    = blend_translucencies(scenecol.rgb, tex3, translucent_albedo);

    if (landMask(scenedepth0) && isEyeInWater==0) scenecol.rgb = simple_fog(scenecol.rgb, dist0, skycol*cave_fix);

    if (isEyeInWater==1) scenecol.rgb = water_fog(scenecol.rgb, dist0, fogcol);

    if (mat_id == 3) {
        if (landMask(scenedepth0)) scenecol.rgb = scenecol.rgb*0.6 + vec3(0.5*v3avg(scenecol.rgb));
        else scenecol.rgb = scenecol.rgb*0.7 + vec3(0.8*v3avg(scenecol.rgb));
    }

    //scenecol.rgb = sqr(scenenormal * 0.5 + 0.5);

    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
}