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

/*
const int colortex0Format   = RGBA16F;
const int colortex1Format   = RGBA16;
const int colortex2Format   = RG16;
const int colortex3Format   = RGBA16F;
const int colortex4Format   = RGBA16F;  
const int colortex5Format   = RGB16F;
const int colortex6Format   = RGBA16F;

const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 1.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);

c0  - 4x16 scene color (full)
c1  - 1x16 encoded normals, 1x16 lightmaps, 2x16 specular texture (gbuffer -> composite2)
c2  - 1x16 matID, 1x16 translucency albedo hue  (gbuffer -> composite2)
c3  - 4x16 translucencies  (water -> composite0), bloom (composite7 -> final)
c4  - temporals (full)
*/

const int noiseTextureResolution = 256;

in vec2 coord;

flat in vec3 atmos_multiscatter;

flat in mat4x3 light_color;
flat in mat2x3 sky_color;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform int frameCounter;

uniform float aspectRatio;
uniform float far, near;

uniform vec2 taaOffset;
uniform vec2 viewSize, pixelSize;

uniform vec3 upvec, upvecView;
uniform vec3 sunvec, sunvecView;
uniform vec3 moonvec, moonvecView;

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

#include "/lib/util/transforms.glsl"

float depth_lin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}

float get_mie(float x, float g) {
    float temp  = 1.0 + pow2(g) - 2.0*g*x;
    return (1.0 - pow2(g)) / ((4.0*pi) * temp*(temp*0.5+0.5));
}

vec3 get_sky(vec3 viewvec) {
    vec3 v      = -viewvec;
    vec3 hvt    = normalize(-upvecView+v);
    vec3 hvb    = normalize(upvecView+v);
    vec3 sv     = normalize(sunvecView+v);
    vec3 mv     = normalize(moonvecView+v);

    float hor_t = dot(hvt, v);
    float hor_b = dot(hvb, v);
    float sun   = 1.0-dot(sv, v);
    float hor   = linStep(1.0-max(hor_t, hor_b), 0.0, 0.2958);

    float hor2  = linStep(1.0-hor_t, 0.0, 0.2958);

    float horizon   = pow5(hor2);
    float zenith    = 1.0-linStep(1.0-hor_t, 0.0, 0.2958);
        zenith      = (exp(-zenith*1.5) + 0.1);

    float vdots     = dot(viewvec, sunvecView);

    float sunscatter = get_mie(vdots, 0.78)*rcp(tau)*(1.0-daytime.w);

    vec3 sky    = sky_color[0]*zenith;
        sky     = mix(sky, sky_color[1], horizon);
        sky    += light_color[0]*sunscatter;

    return sky * 0.9;
}

vec3 get_sun(vec3 viewvec) {
    vec3 v      = -viewvec;
    vec3 sv     = normalize(sunvecView+v);
    float sun   = dot(sv, v);

    const float radius = 0.014;

    float s   = 1.0-linStep(sun, radius, radius + 0.0004);
        //s    *= 1.0-sstep(sun, 0.004, 0.0059)*0.5;

    return s*light_color[0]*100.0;
}

vec3 get_moon(vec3 viewvec, vec3 albedo) {
    vec3 v      = -viewvec;
    vec3 sv     = normalize(moonvecView+v);
    float sun   = dot(sv, v);

    float s   = 1.0-linStep(sun, 0.03, 0.08);

    return albedo*s*light_color[3]*4.0;
}

#include "/lib/atmos/phase.glsl"

/* ------ ambient occlusion and gi ------ */

#include "/lib/frag/bluenoise.glsl"

#include "/lib/light/ao.glsl"

float max_depth3x3(sampler2D depthtex, vec2 coord, vec2 px) {
    float tl    = texture(depthtex, coord + vec2(-px.x, -px.y)).x;
    float tc    = texture(depthtex, coord + vec2(0.0, -px.y)).x;
    float tr    = texture(depthtex, coord + vec2(px.x, -px.y)).x;
    float tmin  = max(tl, max(tc, tr));

    float ml    = texture(depthtex, coord + vec2(-px.x, 0.0)).x;
    float mc    = texture(depthtex, coord).x;
    float mr    = texture(depthtex, coord + vec2(px.x, 0.0)).x;
    float mmin  = max(ml, max(mc, mr));

    float bl    = texture(depthtex, coord + vec2(-px.x, px.y)).x;
    float bc    = texture(depthtex, coord + vec2(0.0, px.y)).x;
    float br    = texture(depthtex, coord + vec2(px.x, px.y)).x;
    float bmin  = max(bl, max(bc, br));

    return max(tmin, max(mmin, bmin));
}

#include "/lib/atmos/project.glsl"

void main() {
    vec4 scenecol   = stex(colortex0);
    float scenedepth = stex(depthtex1).x;

    vec3 viewpos    = screen_viewspace(vec3(coord, scenedepth));
    vec3 viewvec    = normalize(viewpos);
    vec3 scenepos   = view_scenespace(viewpos);
    vec3 svec       = normalize(scenepos);

    //no terrain overhead
    //~2fps
    
    if (!landMask(scenedepth)) {
        vec3 skycol = get_sky(viewvec);

        vec3 sun    = get_sun(viewvec);
        vec3 moonstars = get_moon(viewvec, scenecol.rgb);

        scenecol.rgb = skycol + (sun+moonstars)*sstep(svec.y, -0.04, 0.01);
    }

    vec4 return5    = vec4(0.0);

    if(!(coord.y >= exp2(-SKY_RENDER_LOD) || coord.x >= exp2(-SKY_RENDER_LOD))) {
        vec3 sceneDir = unprojectSky(coord);
        vec3 skycol   = get_sky(mat3(gbufferModelView) * sceneDir);
        return5     = vec4(skycol, 1.0);
    }

    vec4 return3    = vec4(0.0);
    
    #ifdef ambientOcclusion_enabled
        vec2 ao_coord   = (coord)*2.0;

        if (clamp(ao_coord, -0.003, 1.003) == ao_coord) {
            vec2 coord  = ao_coord;
            float d     = max_depth3x3(depthtex1, ao_coord, pixelSize*sqrt(2.0));

            if (landMask(d)) {
                float scenedepth = stex(depthtex1).x;
                vec4 tex1       = stex(colortex1);

                vec3 viewpos    = screen_viewspace(vec3(coord, scenedepth));

                vec3 scenenormal = decodeNormal(tex1.xy);
                vec3 viewnormal = normalize(mat3(gbufferModelView) * scenenormal);

                float ao    = calculate_dbao(depthtex1, scenedepth, coord);
                //float ao    = calculate_ssao(depthtex1, viewpos, viewnormal, ditherBluenoise());

                return3.x   = ao;
            } else {
                return3.x   = 1.0;
            }
        }
    #endif

    /*DRAWBUFFERS:035*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
    gl_FragData[1]  = clampDrawbuffer(return3);
    gl_FragData[2]  = clampDrawbuffer(return5);
}