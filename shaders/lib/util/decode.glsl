float unmap(in float x, float low, float high) {
    if (x < low || x > high) x = low;
    x -= low;
    x /= high-low;
    x /= 0.99;
    x = clamp(x, 0.0, 1.0);
    return x;
}
vec3 decodeColor(float a){
    int bf = int(a*65535.);
    return vec3(bf%32, (bf>>5)%64, bf>>11) / vec3(31,63,31);
}
vec2 decodeV2(float xy) {
    int bf = int(xy*65535.0);
    return vec2( bf%256, bf>>8) / 255.0;
}