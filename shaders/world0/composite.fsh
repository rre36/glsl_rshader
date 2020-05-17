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

const int noiseTextureResolution = 256;

in vec2 coord;

flat in mat4x3 lightColor;
flat in mat2x3 sky_color;

//uniform sampler2D colortex0;
uniform sampler2D colortex5;
uniform sampler2D colortex6;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform float cloudLightFade;
uniform float eyeAltitude;
uniform float frameTimeCounter;
uniform float wetness;

uniform int frameCounter;
uniform int worldTime;

uniform vec2 pixelSize, viewSize;

uniform vec3 cloud_lvec, cloud_lvecView;

uniform vec3 cameraPosition;

uniform vec4 daytime;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;

vec3 screen_viewspace(vec3 screenpos, mat4 projInv) {
    screenpos   = screenpos*2.0-1.0;

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

#include "/lib/atmos/project.glsl"

#include "/lib/frag/bluenoise.glsl"

#include "/lib/util/bicubic.glsl"

#include "/lib/frag/noise.glsl"

vec2 rotate_coord(vec2 pos, const float angle) {
    return vec2(cos(angle)*pos.x + sin(angle)*pos.y, 
                cos(angle)*pos.y - sin(angle)*pos.x);
}

float fbm(vec3 pos, vec3 offset, const float persistence, const float scale, const int octaves) {
    float n     = 0.0;
    float a     = 1.0;
    vec3 shift  = offset;

    for (int i = 0; i<octaves; ++i) {
        n      += value_3d(pos + shift)*a;
        pos.xz  = rotate_coord(pos.xz, pi*0.33);
        pos    *= scale;
        a      *= persistence;
    }

    return n;
}

float cloud_mie_dumb(float cos_theta, float g) {
    float sqG   = sqr(g);
    float a     = (1.0-sqG) / (2.0 + sqG);
    float b     = (1.0 + sqr(cos_theta)) / (1.0 + sqG - 2.0*g*cos_theta);

    return max(1.5 * a*b + g*cos_theta, 0.0)*rcp(pi);
}
float cloud_mie(float x, float g) {
    float mie   = 1.0 + sqr(g) - 2.0*g*x;
        mie     = (1.0 - sqr(g)) / ((4.0*pi) * mie*(mie*0.5+0.5));
    return mie;
}

#include "/lib/atmos/vcloud.glsl"


void compute_vc(out mat2x4 data, in vec3 wvec, vec3 skycol, vec3 wpos, bool terrain) {
    float within    = sstep(eyeAltitude, vcloud_alt-30.0, vcloud_alt) * (1.0-sstep(eyeAltitude, vcloud_maxalt, vcloud_maxalt+30.0));
    bool visible    = (wvec.y>0.0 && eyeAltitude < vcloud_midalt) || (wvec.y<0.0 && eyeAltitude > vcloud_midalt);

    if (visible || within>0.0) {
        bool is_below   = eyeAltitude<vcloud_midalt;

        vec3 bs     = wvec*((vcloud_alt-eyeAltitude)/wvec.y);
        vec3 ts     = wvec*((vcloud_maxalt-eyeAltitude)/wvec.y);

        if (wvec.y<0.0 && is_below || wvec.y>0.0 && !is_below){
            bs = vec3(0.0);
            ts = vec3(0.0);
        }

        vec3 spos   = is_below ? bs : ts;
        vec3 epos   = is_below ? ts : bs;

            spos    = mix(spos, gbufferModelViewInverse[3].xyz, within);
            epos    = mix(epos, wvec*vcloud_clip, within);

        if (terrain) {
            spos    = gbufferModelViewInverse[3].xyz;
            epos    = wpos;
        }

        float dither = ditherBluenoise();

        const float bl  = vcloud_depth/vcloud_samples;
        float stepl     = length((epos-spos)/vcloud_samples);
        float stepcoeff = stepl/bl;
            stepcoeff   = 0.45+clamp(stepcoeff-1.1, 0.0, 4.0)*0.5;
            stepcoeff   = mix(stepcoeff, 6.0, sqr(within));
        int steps       = int(vcloud_samples*stepcoeff);

        vec3 rstep  = (epos-spos)/steps;
        vec3 rpos   = rstep*dither + spos + cameraPosition;
        float rlength = length(rstep);

        vec3 scatter    = vec3(0.0);
        float transmittance = 1.0;
        float fade      = 0.0;
        float fdist     = vcloud_clip + 1.0;

        vec3 sunlight   = (worldTime>23000 || worldTime<12900) ? lightColor[0] * mix(vec3(1.0, 0.3, 0.1), vec3(1.0), sqr(cloudLightFade)) : lightColor[3];
            sunlight   *= cubeSmooth(cloudLightFade);
        vec3 skylight   = sky_color[0] * 0.5;

        float vdotl     = dot(wvec, cloud_lvec);

        float pfade     = saturate(cloud_mie(vdotl, 0.65));

        const float sigma_a = 1.00;         //absorption coeff
        const float sigma_s = 0.30;         //scattering coeff, can technically be assumed to be sigma_t since the albedo is close to 1.0
        const float sigma_t = 0.30;         //extinction coeff, 0.05-0.12 for cumulus, 0.04-0.06 for stratus

        for (int i = 0; i<steps; ++i, rpos += rstep) {
            if (transmittance < 0.05) break;
            if (rpos.y < vcloud_alt || rpos.y > vcloud_maxalt) continue;

            float dist  = distance(rpos, cameraPosition);
            if (dist > vcloud_clip) continue;
            float dfade = saturate(dist/vcloud_clip);
            //if ((1.0-dfade)<0.01) continue;

            float density   = vcloud_shape(rpos);
            if (density<=0.0) continue;
            
            float f     = linStep(dfade, 0.75, 0.99);

            if (fdist>vcloud_clip) {
                fdist   = dist;
                fade    = f;
            } else {
                fdist   = mix(fdist, dist, transmittance);
                fade    = mix(fade, f, transmittance);
            }


            float extinction = density * sigma_t;
            float stept     = expf(-extinction*rlength);
            float integral  = (1.0 - stept) / sigma_t;

            vec3 result_s   = vec3(0.0);

            float directod  = vc_directOD(rpos, 5)*sigma_a;
            float skyod     = vc_skyOD(rpos, 3)*sigma_a;

            float powder    = 1.0 - expf(-density * vc_powder_K);
            float dpowder   = mix(powder, 1.0, pfade);

            /*
            for (int j = 0; j<5; ++j) {
                float n     = float(j);

                float s_d   = sigma_s * pow(0.5, n);    //scatter derivate
                float t_d   = sigma_t * pow(0.5, n);    //transmittance/attentuation derivate
                float phase = cloud_phase(vdotl, pow(0.5, n));  //phase derivate

                result_s.x += expf(-directod*t_d) * phase * dpowder * s_d;
                result_s.y += expf(-skyod*t_d) * powder * s_d;
            }*/

            #define multiscatter_coeff 0.4

            float phase = cloud_phase(vdotl, 1.0);
            float phase2 = cloud_phase(vdotl, multiscatter_coeff);

            result_s.x += (expf(-directod * sigma_t) * phase + expf(-directod * sigma_t * multiscatter_coeff) * phase2 * multiscatter_coeff) * dpowder * sigma_s;
            result_s.y += (expf(-skyod * sigma_t) + expf(-skyod * sigma_t * multiscatter_coeff) * multiscatter_coeff) * powder * sigma_s;

            scatter    += result_s * integral * transmittance;

            transmittance *= stept;
        }
        //if (fdist < -0.5) fdist = vcloud_clip;
        transmittance = linStep(transmittance, 0.05, 1.0);
        scatter.x *= 3.0;

        vec3 color  = (sunlight*scatter.x) + (skylight*scatter.y);

        fade        = saturate(1.0-fade);
        /*
        fade    = linStep(fdist, 0.75 * vcloud_clip, 0.99 * vcloud_clip);
        fade    = saturate(1.0-fade);
        fade    = sqr(fade);*/

        const vec3 extinct_coeff = vec3(3e-4);

        vec3 atmosfade  = expf(-extinct_coeff * vec3(fdist));
        float skyfade   = expf(-fdist * cloud_atmos_density);

            //transmittance *= fade;
            //color      *= fade;

        data[0]     = vec4(color, transmittance);
        data[1]     = vec4(atmosfade * skyfade * fade, 1.0);

        //scenecol    = mix(skycol, scenecol, transmittance);
        //scenecol    = mix(scenecol, scenecol * transmittance + color, atmosfade * skyfade);
    } else {
        data[0]     = vec4(0.0, 0.0, 0.0, 1.0);
        data[1]     = vec4(0.0);
    }
}

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

void main() {
    vec4 return6    = stex(colortex6);
    vec4 return5    = stex(colortex5);

    mat2x4 cloud_data = mat2x4(0.0);
        cloud_data[0] = vec4(0.0, 0.0, 0.0, 1.0);
        cloud_data[1] = vec4(0.0);

    const float cLOD    = sqrt(CLOUD_RENDER_LOD);

    vec2 scalecoord  = (coord-vec2(1.0-rcp(cLOD), 0.0))*cLOD;

    float d     = max_depth3x3(depthtex1, scalecoord, pixelSize*cLOD);

    if (clamp(scalecoord, -0.003, 1.003) == scalecoord) {
        scalecoord      = clamp(scalecoord, 0.0, 1.0);
        vec3 viewpos    = screen_viewspace(vec3(scalecoord, texture(depthtex1, scalecoord)));
        vec3 viewvec    = normalize(viewpos);
        vec3 scenepos   = view_scenespace(viewpos);

        bool is_cloud   = ((scenepos.y + eyeAltitude) > vcloud_alt && eyeAltitude < vcloud_alt) ||
                        ((scenepos.y + eyeAltitude) < vcloud_maxalt && eyeAltitude > vcloud_maxalt);
            is_cloud    = is_cloud || (eyeAltitude > vcloud_alt && eyeAltitude < vcloud_maxalt);

        if (!landMask(d) || is_cloud) {
            vec3 svec       = normalize(scenepos);
            compute_vc(cloud_data, svec, textureBicubic(colortex5, projectSky(svec)).rgb, scenepos, landMask(d));
            return6     = cloud_data[0];
            return5     = cloud_data[1];
        }
    }

    /*DRAWBUFFERS:56*/
    gl_FragData[0]  = clampDrawbuffer(return5);
    gl_FragData[1]  = clampDrawbuffer(return6);
}