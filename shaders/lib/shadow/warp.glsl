#define warpMethod 1        //[0 1]0-off 1-robobo

#define warpStrength 0.0    //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]

#if warpMethod==0
    void warpShadowmap(inout vec2 coord, out float distortion) {
        distortion = 1.0;
        coord = coord;
    }
    void warpShadowmap(inout vec2 coord) {
        coord = coord;
    }

#elif warpMethod==1

    #define shadowmapBias 0.85

    float getWarpFactor(in vec2 x) {
        return length(x * 1.169) * shadowmapBias + (1.0 - shadowmapBias);
    }

    void warpShadowmap(inout vec2 coord, out float distortion) {
        distortion = getWarpFactor(coord);
        coord /= distortion;
    }
    void warpShadowmap(inout vec2 coord) {
        float distortion = getWarpFactor(coord);
        coord /= distortion;
    }
#endif

//log warping
/*
    float getWarpFactor(in vec2 x) {
        float nearQuality   = 0.11;
        float farQuality    = 1.1;
        float a     = exp(nearQuality);
        float b     = (exp(farQuality)-a)*(shadowDistance/128.0);
        return log(length(x)*b+a);
    }

    void warpShadowmap(inout vec2 coord, out float distortion) {
        distortion = getWarpFactor(coord);
        coord /= distortion;
    }
    void warpShadowmap(inout vec2 coord) {
        float distortion = getWarpFactor(coord);
        coord /= distortion;
    */