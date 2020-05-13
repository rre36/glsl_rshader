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

//bloom downsampling method based on chocapic13's shaders
//merge and upsample blurs

uniform sampler2D colortex3;

uniform vec2 pixelSize;
uniform vec2 viewSize;

in vec2 coord;

vec4 textureBicubic(sampler2D sampler, vec2 coord) {
	vec2 res = textureSize(sampler, 0);

	coord = coord * res - 0.5;

	vec2 f = fract(coord);
	coord -= f;

	vec2 ff = f * f;
	vec4 w0;
	vec4 w1;
	w0.xz = 1 - f; w0.xz *= w0.xz * w0.xz;
	w1.yw = ff * f;
	w1.xz = 3 * w1.yw + 4 - 6 * ff;
	w0.yw = 6 - w1.xz - w1.yw - w0.xz;

	vec4 s = w0 + w1;
	vec4 c = coord.xxyy + vec2(-0.5, 1.5).xyxy + w1 / s;
	c /= res.xxyy;

	vec2 m = s.xz / (s.xz + s.yw);
	return mix(
		mix(texture(sampler, c.yw), texture(sampler, c.xw), m.x),
		mix(texture(sampler, c.yz), texture(sampler, c.xz), m.x),
		m.y);
}

void main() {
	if (clamp(coord, -0.003, 1.003) != coord) discard;
    vec2 tcoord     = (gl_FragCoord.xy*2.0+0.5)*pixelSize;
    vec2 rscale     = vec2(1920.0, 1080.0)/max(viewSize, vec2(1920.0, 1080.0));
	vec3 blur       = vec3(0.0);

		blur 	   += textureBicubic(colortex3, (tcoord+vec2(0.0, 0.5))/2.0).rgb;    //1:4

        blur       += textureBicubic(colortex3, tcoord/4.0).rgb;    //1:8

        blur       += textureBicubic(colortex3, tcoord/8.0+vec2(0.25*rscale.x+2.0*pixelSize.x, 0.0)).rgb;   //1:16

        blur       += textureBicubic(colortex3, tcoord/16.0+vec2(0.375*rscale.x+4.0*pixelSize.x, 0.0)).rgb;   //1:32

        blur       += textureBicubic(colortex3, tcoord/32.0+vec2(0.4375*rscale.x+6.0*pixelSize.x, 0.0)).rgb;   //1:64

        blur       += textureBicubic(colortex3, tcoord/64.0+vec2(0.46875*rscale.x+8.0*pixelSize.x, 0.0)).rgb;   //1:128

        blur       += textureBicubic(colortex3, tcoord/128.0+vec2(0.484375*rscale.x+10.0*pixelSize.x, 0.0)).rgb;   //1:256

		blur       *= 0.5;

		//blur 		= texture(colortex3, gl_FragCoord.xy*pixelSize).rgb;
		
    /*DRAWBUFFERS:3*/
    gl_FragData[0]  = clampDrawbuffer(blur);
}