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
this is the sky projection lee did in ymir
*/


vec2 projectSky(vec3 dir, float lod) {
	float tileSize       = min(floor(viewSize.x * 0.5) / 1.5, floor(viewSize.y * 0.5)) * exp2(-lod);
	float tileSizeDivide = (0.5 * tileSize) - 1.5;

	vec2 coord;
	if (abs(dir.x) > abs(dir.y) && abs(dir.x) > abs(dir.z)) {
		dir /= abs(dir.x);
		coord.x = dir.y * tileSizeDivide + tileSize * 0.5;
		coord.y = dir.z * tileSizeDivide + tileSize * (dir.x < 0.0 ? 0.5 : 1.5);
	} else if (abs(dir.y) > abs(dir.x) && abs(dir.y) > abs(dir.z)) {
		dir /= abs(dir.y);
		coord.x = dir.x * tileSizeDivide + tileSize * 1.5;
		coord.y = dir.z * tileSizeDivide + tileSize * (dir.y < 0.0 ? 0.5 : 1.5);
	} else {
		dir /= abs(dir.z);
		coord.x = dir.x * tileSizeDivide + tileSize * 2.5;
		coord.y = dir.y * tileSizeDivide + tileSize * (dir.z < 0.0 ? 0.5 : 1.5);
	}

	return coord / viewSize;
}

vec3 unprojectSky(vec2 coord, float lod) {
	coord *= viewSize;
	float tileSize       = min(floor(viewSize.x * 0.5) / 1.5, floor(viewSize.y * 0.5)) * exp2(-lod);
	float tileSizeDivide = (0.5 * tileSize) - 1.5;

	vec3 direction = vec3(0.0);

	if (coord.x < tileSize) {
		direction.x =  coord.y < tileSize ? -1 : 1;
		direction.y = (coord.x - tileSize * 0.5) / tileSizeDivide;
		direction.z = (coord.y - tileSize * (coord.y < tileSize ? 0.5 : 1.5)) / tileSizeDivide;
	} else if (coord.x < 2.0 * tileSize) {
		direction.x = (coord.x - tileSize * 1.5) / tileSizeDivide;
		direction.y =  coord.y < tileSize ? -1 : 1;
		direction.z = (coord.y - tileSize * (coord.y < tileSize ? 0.5 : 1.5)) / tileSizeDivide;
	} else {
		direction.x = (coord.x - tileSize * 2.5) / tileSizeDivide;
		direction.y = (coord.y - tileSize * (coord.y < tileSize ? 0.5 : 1.5)) / tileSizeDivide;
		direction.z =  coord.y < tileSize ? -1 : 1;
	}

	return normalize(direction);
}

vec2 projectSky(vec3 dir) {
	return projectSky(dir, SKY_RENDER_LOD);
}

vec3 unprojectSky(vec2 coord) {
	return unprojectSky(coord, SKY_RENDER_LOD);
}