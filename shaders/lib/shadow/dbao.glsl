void dbao(in float falloff) {
    if (falloff > 0.01) {
    float ao            = 0.0;
    float dither        = ditherDynamic;

    #if setAOQuality==0
        const int aoArea    = 3;
        const int samples   = 2;
    #elif setAOQuality==1
        const int aoArea    = 3;
        const int samples   = 3;
    #elif setAOQuality==2
        const int aoArea    = 4;
        const int samples   = 4;
    #endif
    
    float size          = 2.8/samples;
        size           *= dither;
    const float piAngle = 22.0/(7.0*180.0);
    float radius        = 0.6/samples;
    float rot           = 180.0/aoArea*(dither+0.5);
    vec2 scale          = vec2(1.0/aspectRatio,1.0) * gbufferProjection[1][1] / (2.74747742 * max(far*depth.linear,6.0));
    float sd            = 0.0;
    float angle         = 0.0;
    float dist          = 0.0;

    for (int i = 0; i<samples; i++) {
        for (int j = 0; j<aoArea; j++) {
            sd          = depthLin(textureLod(depthtex1, coord+vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale, 0).r);
            float samp  = far*(depth.linear-sd)/size;
            angle       = clamp(0.5-samp, 0.0, 1.0);
            dist        = clamp(0.0625*samp, 0.0, 1.0);
            sd          = depthLin(textureLod(depthtex1, coord-vec2(cos(rot*piAngle), sin(rot*piAngle))*size*scale, 0).r);
            samp        = far*(depth.linear-sd)/size;
            angle      += clamp(0.5-samp, 0.0, 1.0);
            dist       += clamp(0.0625*samp, 0.0, 1.0);
            ao         += clamp(angle+dist, 0.0, 1.0);
            rot        += 180.0/aoArea;
        }
        rot    += 180.0/aoArea;
        size   += radius;
        angle   = 0.0;
        dist    = 0.0;
    }
    ao         /= samples+aoArea;
    ao          = (ao*sqrt(ao))*0.5;
    ao          = saturate(ao);
    ao          = 1.0-ao;
    ao          = 1.0-ao*falloff;
    ao          = ao*0.8+0.2;
    sdata.ao    = ao;
    }
}