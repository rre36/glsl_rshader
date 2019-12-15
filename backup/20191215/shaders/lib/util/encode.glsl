float remap(in float x, float low, float high) {
    x = clamp(x, 0.0, 1.0);
    x *= high-low;
    x *= 0.99;
    if (x > 0.0) x += low;
    return x;
}

float bayer2e(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}
#define bayer4e(a)   (bayer2e( .5*(a))*.25+bayer2e(a))

float encodeV2(float x, float y) {
    ivec2 source    = ivec2(vec2(x, y)*255.0);
    return float(source.x|(source.y<<8) ) / 65535.0;
}
float encodeV2(vec2 x) {
    ivec2 source    = ivec2(x*255.0);
    return float(source.x|(source.y<<8) ) / 65535.0;
}

#define m vec3(31,63,31)
float encodeV3(float x, float y, float z){
    vec3 a  = vec3(x, y, z);
    float dither = bayer4e(gl_FragCoord.xy);
    a += (dither-.5) / m;
    a = clamp(a, 0., 1.);
    ivec3 b = ivec3(a*m);
    return float( b.r|(b.g<<5)|(b.b<<11) ) / 65535.;
}
float encodeV3(vec3 a){
    float dither = bayer4e(gl_FragCoord.xy);
    a += (dither-.5) / m;
    a = clamp(a, 0., 1.);
    ivec3 b = ivec3(a*m);
    return float( b.r|(b.g<<5)|(b.b<<11) ) / 65535.;
}
#undef m