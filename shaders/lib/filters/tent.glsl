vec2 tentOffsets[4] = vec2[4] (
    vec2(0.5, -0.5), vec2(0.5, 0.5),
    vec2(-0.5, -0.5), vec2(-0.5, 0.5)
);


vec4 f4x4(sampler2D tex) {
    vec2 pixelRad   = 1.0/vec2(viewWidth, viewHeight);
    vec4 col        = vec4(0.0);

    for (int i = 0; i<4; i++) {
        col += texture(tex, coord + tentOffsets[i]*pixelRad*2.0);
    }
    return col/4;
}

vec4 tent(sampler2D tex, const float scaleCoord) {
    vec2 pixelRad   = 1.0/vec2(viewWidth, viewHeight);
    vec4 col        = vec4(0.0);

    for (int i = 0; i<4; i++) {
        col += texture(tex, coord*scaleCoord + tentOffsets[i]*pixelRad);
    }
    return col/4;
}
vec4 tent(sampler2D tex) {
    vec2 pixelRad   = 1.0/vec2(viewWidth, viewHeight);
    vec4 col        = vec4(0.0);

    for (int i = 0; i<4; i++) {
        col += texture(tex, coord + tentOffsets[i]*pixelRad);
    }
    return col/4;
}
vec4 tent(sampler2D tex, const int LOD) {
    vec2 pixelRad   = 1.0/vec2(viewWidth, viewHeight);
    vec4 col        = vec4(0.0);

    for (int i = 0; i<4; i++) {
        col += textureLod(tex, coord + tentOffsets[i]*pixelRad, LOD);
    }
    return col/4;
}