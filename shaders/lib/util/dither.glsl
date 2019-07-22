float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}
#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))
#define bayer256(a) (bayer128(.5*(a))*.25+bayer2(a))

float ditherGradNoise(){
    return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y));
} 

float ditherGradNoiseTemporal(){
    return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y +0.00623715 *(frameCounter)));
}

float bayer64s          = bayer64(gl_FragCoord.xy);
float bayer64t          = fract(bayer64s + frameCounter/8.0);
float ditherStatic      = ditherGradNoise();
float ditherTemporal    = ditherGradNoiseTemporal();
#ifdef temporalAA
float ditherDynamic     = ditherTemporal;
#else
float ditherDynamic     = ditherStatic;
#endif