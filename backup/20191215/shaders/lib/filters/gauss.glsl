const float gauss9w[9] = float[9] (
     0.0779, 0.12325, 0.0779,
    0.12325, 0.1954,  0.12225,
     0.0779, 0.12325, 0.0779
);

const vec2 gauss9o[9] = vec2[9] (
    vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0),
    vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(-1.0, 0.0),
    vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, -1.0)
);

const float gauss25w[25] = float[25] (
  0.0038, 0.0150, 0.0238, 0.0150, 0.0038,
  0.0150, 0.0599, 0.0949, 0.0599, 0.0150,
  0.0238, 0.0949, 0.1503, 0.0949, 0.0238,
  0.0150, 0.0599, 0.0949, 0.0599, 0.0150,
  0.0038, 0.0150, 0.0238, 0.0150, 0.0038
);

const vec2 gauss25o[25] = vec2[25] (
    vec2(2.0, 2.0), vec2(1.0, 2.0), vec2(0.0, 2.0), vec2(-1.0, 2.0), vec2(-2.0, 2.0),
    vec2(2.0, 1.0), vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0), vec2(-2.0, 1.0),
    vec2(2.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(-1.0, 0.0), vec2(-2.0, 0.0),
    vec2(2.0, -1.0), vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, -1.0), vec2(-2.0, -1.0),
    vec2(2.0, -2.0), vec2(1.0, -2.0), vec2(0.0, -2.0), vec2(-1.0, -2.0), vec2(-2.0, -2.0)
);

const float gauss49w[49] = float[49] (
    0.0000, 0.0004, 0.0014, 0.0023, 0.0014, 0.0004, 0.0000,
    0.0004, 0.0037, 0.0147, 0.0232, 0.0147, 0.0037, 0.0004,
    0.0014, 0.0147, 0.0585, 0.0927, 0.0585, 0.0147, 0.0014,
    0.0023, 0.0232, 0.0927, 0.1468, 0.0927, 0.0232, 0.0023,
    0.0014, 0.0147, 0.0585, 0.0927, 0.0585, 0.0147, 0.0014,
    0.0004, 0.0037, 0.0147, 0.0232, 0.0147, 0.0037, 0.0004,
    0.0000, 0.0004, 0.0014, 0.0023, 0.0014, 0.0004, 0.0000
);

const vec2 gauss49o[49] = vec2[49] (
    vec2(3.0, 3.0), vec2(2.0, 3.0), vec2(1.0, 3.0), vec2(0.0, 3.0), vec2(-1.0, 3.0), vec2(-2.0, 3.0), vec2(-3.0, 3.0),
    vec2(3.0, 2.0), vec2(2.0, 2.0), vec2(1.0, 2.0), vec2(0.0, 2.0), vec2(-1.0, 2.0), vec2(-2.0, 2.0), vec2(-3.0, 2.0),
    vec2(3.0, 1.0), vec2(2.0, 1.0), vec2(1.0, 1.0), vec2(0.0, 1.0), vec2(-1.0, 1.0), vec2(-2.0, 1.0), vec2(-3.0, 1.0),
    vec2(3.0, 0.0), vec2(2.0, 0.0), vec2(1.0, 0.0), vec2(0.0, 0.0), vec2(-1.0, 0.0), vec2(-2.0, 0.0), vec2(-3.0, 0.0),
    vec2(3.0, -1.0), vec2(2.0, -1.0), vec2(1.0, -1.0), vec2(0.0, -1.0), vec2(-1.0, -1.0), vec2(-2.0, -1.0), vec2(-3.0, -1.0),
    vec2(3.0, -2.0), vec2(2.0, -2.0), vec2(1.0, -2.0), vec2(0.0, -2.0), vec2(-1.0, -2.0), vec2(-2.0, -2.0), vec2(-3.0, -2.0),
    vec2(3.0, -3.0), vec2(2.0, -3.0), vec2(1.0, -3.0), vec2(0.0, -3.0), vec2(-1.0, -3.0), vec2(-2.0, -3.0), vec2(-3.0, -3.0)
);

vec4 gauss9(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord + gauss9o[i]*pixelRad;
        col += texture2D(tex, bcoord)*gauss9w[i];
    }
    return col;
}
vec4 gauss9flat(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord + gauss9o[i]*pixelRad;
        col += texture2D(tex, bcoord);
    }
    col /= 9;
    return col;
}
vec4 gauss9flex(sampler2D tex, vec2 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<9; i++) {
        vec2 bcoord = coord + gauss9o[i]*sigma;
        col += texture2D(tex, bcoord)*gauss9w[i];
    }
    return col;
}

vec4 gauss25(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord + gauss25o[i]*pixelRad;
        col += texture2D(tex, bcoord)*gauss25w[i];
    }
    return col;
}
vec4 gauss25flat(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord + gauss25o[i]*pixelRad;
        col += texture2D(tex, bcoord);
    }
    col /= 25;
    return col;
}
vec4 gauss25flex(sampler2D tex, vec2 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<25; i++) {
        vec2 bcoord = coord + gauss25o[i]*sigma;
        col += texture2D(tex, bcoord)*gauss25w[i];
    }
    return col;
}

vec4 gauss49(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec4 col = vec4(0.0);

    for (int i = 0; i<49; i++) {
        vec2 bcoord = coord + gauss49o[i]*pixelRad;
        col += texture2D(tex, bcoord)*gauss49w[i];
    }
    return col;
}
vec4 gauss49flat(sampler2D tex, float sigma) {
    vec2 pixelRad = sigma/vec2(viewWidth, viewHeight);
    vec4 col = vec4(0.0);

    for (int i = 0; i<49; i++) {
        vec2 bcoord = coord + gauss49o[i]*pixelRad;
        col += texture2D(tex, bcoord);
    }
    col /= 25;
    return col;
}
vec4 gauss49flex(sampler2D tex, vec2 coord, float sigma) {
    vec4 col = vec4(0.0);

    for (int i = 0; i<49; i++) {
        vec2 bcoord = coord + gauss49o[i]*sigma;
        col += texture2D(tex, bcoord)*gauss49w[i];
    }
    return col;
}