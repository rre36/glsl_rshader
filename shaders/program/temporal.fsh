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

/*
temporal anti aliasing based on
- bsl shaders
- chocapic13 shaders
- unreal 4
*/

#include "/lib/common.glsl"

const bool colortex0MipmapEnabled = true;

const bool colortex4Clear   = false;

in vec2 coord;

flat in float exposure;

uniform sampler2D colortex0;
uniform sampler2D colortex4;

uniform sampler2D depthtex1;

uniform float frameTime;
uniform float viewHeight;
uniform float viewWidth;
uniform float nightVision;

uniform vec2 pixelSize, viewSize;
uniform vec2 taaOffset;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;

vec2 taa_reproject(vec2 coord, float depth) {
    float hand  = float(depth > 0.56);
    vec4 pos    = vec4(coord, depth, 1.0)*2.0-1.0;
        pos     = gbufferProjectionInverse*pos;
        pos    /= pos.w;
        pos     = gbufferModelViewInverse*pos;

    vec4 ppos   = pos + vec4(cameraPosition-previousCameraPosition, 0.0)*hand;
        ppos    = gbufferPreviousModelView*ppos;
        ppos    = gbufferPreviousProjection*ppos;

    return (ppos.xy/ppos.w)*0.5+0.5;
}
vec2 taa_reproject(vec3 coord, float depth) {
    float hand  = float(depth > 0.56);
    vec3 pos    = coord*2.0-1.0;
        pos     = projMAD(gbufferProjectionInverse, pos);
        pos     = viewMAD(gbufferModelViewInverse, pos);

    vec3 ppos   = pos + (cameraPosition-previousCameraPosition)*hand;
        ppos    = viewMAD(gbufferPreviousModelView, ppos);
        ppos    = projMAD(gbufferPreviousProjection, ppos);

    return ppos.xy*0.5+0.5;
}

//3x3 screenpos sampling based on chocapic13's taa
vec3 screenpos3x3(sampler2D depth) {
    vec2 dx     = vec2(pixelSize.x, 0.0);
    vec2 dy     = vec2(0.0, pixelSize.y);

    vec3 dtl    = vec3(coord, 0.0)  + vec3(-pixelSize, texture(depth, coord - dx - dy).x);
    vec3 dtc    = vec3(coord, 0.0)  + vec3(0.0, -pixelSize.y, texture(depth, coord - dy).x);
    vec3 dtr    = vec3(coord, 0.0)  + vec3(pixelSize.x, -pixelSize.y, texture(depth, coord - dy + dx).x);

    vec3 dml    = vec3(coord, 0.0)  + vec3(-pixelSize.x, 0.0, texture(depth, coord - dx).x);
    vec3 dmc    = vec3(coord, 0.0)  + vec3(0.0, 0.0, texture(depth, coord).x);
    vec3 dmr    = vec3(coord, 0.0)  + vec3(0.0, pixelSize.y,  texture(depth, coord + dx).x);

    vec3 dbl    = vec3(coord, 0.0)  + vec3(-pixelSize.x, pixelSize.y, texture(depth, coord + dy - dx).x);
    vec3 dbc    = vec3(coord, 0.0)  + vec3(0.0, pixelSize.y, texture(depth, coord + dy).x);
    vec3 dbr    = vec3(coord, 0.0)  + vec3(pixelSize.x, pixelSize.y, texture(depth, coord + dy + dx).x);

    vec3 dmin   = dmc;

    dmin    = dmin.z > dtc.z ? dtc : dmin;
    dmin    = dmin.z > dtr.z ? dtr : dmin;

    dmin    = dmin.z > dml.z ? dml : dmin;
    dmin    = dmin.z > dtl.z ? dtl : dmin;
    dmin    = dmin.z > dmr.z ? dmr : dmin;

    dmin    = dmin.z > dbl.z ? dbl : dmin;
    dmin    = dmin.z > dbc.z ? dbc : dmin;
    dmin    = dmin.z > dbr.z ? dbr : dmin;

    return dmin;
}

vec4 texture_catmullrom(sampler2D tex, vec2 uv) {   //~5fps
    vec2 res    = textureSize(tex, 0);

    vec2 coord  = uv*res;
    vec2 coord1 = floor(coord - 0.5) + 0.5;

    vec2 f      = coord-coord1;

    vec2 w0     = f * (-0.5 + f * (1.0 - (0.5 * f)));
    vec2 w1     = 1.0 + pow2(f) * (-2.5 + (1.5 * f));
    vec2 w2     = f * (0.5 + f * (2.0 - (1.5 * f)));
    vec2 w3     = pow2(f) * (-0.5 + (0.5 * f));

    vec2 w12    = w1+w2;
    vec2 delta12 = w2 * rcp(w12);

    vec2 uv0    = (coord1 - vec2(1.0)) * pixelSize;
    vec2 uv3    = (coord1 + vec2(1.0)) * pixelSize;
    vec2 uv12   = (coord1 + delta12) * pixelSize;

    vec4 col    = vec4(0.0);
        col    += textureLod(tex, vec2(uv0.x, uv0.y), 0)*w0.x*w0.y;
        col    += textureLod(tex, vec2(uv12.x, uv0.y), 0)*w12.x*w0.y;
        col    += textureLod(tex, vec2(uv3.x, uv0.y), 0)*w3.x*w0.y;

        col    += textureLod(tex, vec2(uv0.x, uv12.y), 0)*w0.x*w12.y;
        col    += textureLod(tex, vec2(uv12.x, uv12.y), 0)*w12.x*w12.y;
        col    += textureLod(tex, vec2(uv3.x, uv12.y), 0)*w3.x*w12.y;

        col    += textureLod(tex, vec2(uv0.x, uv3.y), 0)*w0.x*w3.y;
        col    += textureLod(tex, vec2(uv12.x, uv3.y), 0)*w12.x*w3.y;
        col    += textureLod(tex, vec2(uv3.x, uv3.y), 0)*w3.x*w3.y;

    return clamp(col, 0.0, 65535.0);
}

#define taa_blend 0.2
#define taa_mreject 0.5
#define taa_antighost 1.0
#define taa_antiflicker 0.6
#define taa_catmullrom

vec3 get_taa(vec3 scenecol, float scenedepth) {
    vec3 screen3x3  = screenpos3x3(depthtex1);

    vec2 rcoord     = taa_reproject(coord, scenedepth);

    vec2 px_dist    = 0.5-abs(fract((rcoord-coord)*viewSize)-0.5);

    //motion rejection
    float bweight   = dot(px_dist, px_dist);
        bweight     = pow(bweight, 1.5)*taa_mreject;

    if (clamp(rcoord, 0.0, 1.0) != rcoord) return scenecol;

    vec3 coltl   = textureLod(colortex0,coord+vec2(-pixelSize.x, -pixelSize.y),0).rgb;
	vec3 coltm   = textureLod(colortex0,coord+vec2( 0.0,         -pixelSize.y),0).rgb;
	vec3 coltr   = textureLod(colortex0,coord+vec2( pixelSize.x, -pixelSize.y),0).rgb;
	vec3 colml   = textureLod(colortex0,coord+vec2(-pixelSize.x, 0.0         ),0).rgb;
	vec3 colmr   = textureLod(colortex0,coord+vec2( pixelSize.x, 0.0         ),0).rgb;
	vec3 colbl   = textureLod(colortex0,coord+vec2(-pixelSize.x,  pixelSize.y),0).rgb;
	vec3 colbm   = textureLod(colortex0,coord+vec2( 0.0,          pixelSize.x),0).rgb;
	vec3 colbr   = textureLod(colortex0,coord+vec2( pixelSize.x,  pixelSize.y),0).rgb;

	vec3 min_col = min(scenecol,min(min(min(coltl,coltm),min(coltr,colml)),min(min(colmr,colbl),min(colbm,colbr))));
	vec3 max_col = max(scenecol,max(max(max(coltl,coltm),max(coltr,colml)),max(max(colmr,colbl),max(colbm,colbr))));
/*
    vec3 c1     = scenecol + coltl + coltm + coltr + colml + colmr + colbl + colbm + colbr;
    vec3 c2     = pow2(scenecol) + pow2(coltl) + pow2(coltm) + pow2(coltr) + pow2(colml) + pow2(colmr) + pow2(colbl) + pow2(colbm) + pow2(colbr);

    vec3 c      = c1*rcp(9.0);
    vec3 sigma  = sqrt(c2*rcp(9.0) - pow2(c));
*/
    #ifdef taa_catmullrom
        vec3 repcol = texture_catmullrom(colortex4, rcoord).rgb;
    #else
        vec3 repcol = texture(colortex4, rcoord).rgb;
    #endif

    vec3 taacol = clamp(repcol, min_col, max_col);

    float clamped = flength(repcol - taacol) * rcp(getLuma(repcol));


    //flicker reduction
    float ldiff     = flength(repcol - scenecol) * rcp(getLuma(repcol));
        ldiff       = 1.0-saturate(pow2(ldiff)) * taa_antiflicker;
    
    vec2 vel    = (coord-rcoord)/pixelSize;

    float taa_weight = saturate(1.0-sqrt(flength(vel))/2.0)*0.9;

    if (landMask(scenedepth)) taa_weight   = max(taa_weight, 0.05);
    else taa_weight     = max(taa_weight, 0.9);

    float lb    = taa_blend;
    if (!landMask(scenedepth)) lb = 0.1;

    taa_weight  = mix(taa_weight, 0.99, 1.0-saturate((ldiff*lb) + (clamped*taa_antighost) + bweight));

    taacol.rgb  = mix(scenecol.rgb, taacol.rgb, taa_weight);

    return taacol;
}
/*
float get_imageLuma(sampler2D tex) {
    vec3 sample1    = textureLod(tex, vec2(0.5), ceil(log2(max(viewHeight, viewWidth))*1.5)).rgb;
    //vec3 sample2    = textureLod(tex, vec2(0.5), ceil(log2(max(viewHeight, viewWidth)))*rcp(1.5)).rgb;

    return getLuma(sample1);
}

float temporal_exp() {
    float exp_curr  = clamp(texture(colortex4, vec2(0.5)).a, 0.0, 65535.0);
    float exp_targ  = rcp(get_imageLuma(colortex0));
        exp_targ    = clamp(exp_targ, 2.0, 50.0 * rcp(exposure_minlum) + nightVision*15.0);
        exp_targ    = log2(exp_targ / 8.0);    //adjust this
        exp_targ    = 1.2 * pow(2.0, exp_targ);

    return mix(exp_curr, exp_targ, 0.035 * exposure_speed * (frameTime/0.033));
}*/

void main() {
    vec4 scenecol   = stexLod(colortex0, 0);
    float scenedepth = stex(depthtex1).x;

    #ifdef taa_enabled
    vec3 temporal   = get_taa(scenecol.rgb, scenedepth);
        scenecol.rgb = temporal;
    #else
    const vec3 temporal   = vec3(0.0);
    #endif

    //float exposure  = temporal_exp();

    /*DRAWBUFFERS:034*/
    gl_FragData[0]  = makeDrawbuffer(scenecol);
    gl_FragData[1]  = vec4(0.0, 0.0, 0.0, 1.0);
    gl_FragData[2]  = vec4(temporal, exposure);
}