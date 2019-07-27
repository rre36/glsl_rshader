float noise3D(in vec3 pos) {
    vec3 i          = floor(pos);
    vec3 f          = fract(pos);

    vec2 p1         = (i.xy+i.z*vec2(17.0)+f.xy);
    vec2 p2         = (i.xy+(i.z+1.f)*vec2(17.0))+f.xy;
    vec2 c1         = (p1+0.5)/1024;
    vec2 c2         = (p2+0.5)/1024;
    float r1        = texture(noisetex, c1).r;
    float r2        = texture(noisetex, c2).r;
    return mix(r1, r2, f.z);
}

float vc_shape(in vec3 pos) {
    vec3 pos0 = pos/150.0;

    float tick  = -frameTimeCounter*0.5;

    pos0.x  -= tick*0.02;

    //pos0    -= (noise3D(pos0+vec3(0.0, tick*0.01, 0.0))*2.0-1.0)*0.3;

    vec3 pos1   = pos0*vec3(1.0, 0.5, 1.0)+vec3(0.0, tick*0.01, 0.0);

    float shape = noise3D(pos0*vec3(1.0, 0.5, 1.0) + vec3(0.0, tick*0.01, 0.0));
        pos0 *= 4.0; pos0.x -= tick*0.02;
        shape  += (1.0-abs(noise3D(pos0)*3.0-1.0))*0.2;
        pos0 *= 4.0; pos0.x -= tick*0.05;
        shape  += (1.0-abs(noise3D(pos0)*3.0-1.0))*0.075;

        #if s_vcDetail>=1
            pos0 *= 4.0; pos0.x -= tick*0.03;
            shape  += (1.0-abs(noise3D(pos0)*3.0-1.0))*0.025;
        #endif

    float lowFade   = sstep(pos.y, vc_lowEdge, vc_lowEdge+vc_thickness*0.08);
    float highFade  = 1.0-sstep(pos.y, vc_highEdge-vc_thickness*0.1, vc_highEdge);

    float lowCov    = 1.0-sstep(pos.y, vc_lowEdge, vc_altitude-vc_thickness*0.15);
        lowCov      = pow2(lowCov);
    float highCov   = sstep(pos.y, vc_lowEdge+vc_thickness*0.2, vc_highEdge);

        shape      -= lowCov*0.4;
        shape      -= highCov*0.4;
        shape      *= lowFade*highFade;

    float coverage    = mix(0.4*s_vcCoverage, 0.8, wetness);
    const float density = 0.82*((s_vcDensity-1.0)*0.1+1.0);
        shape       = max(shape-(1.0-coverage), 0.0)/(1.0-density);

    return max(shape, 0.0);
}

float vc_lD(in vec3 rPos, const int steps) {
    float density       = 0.15;

    float stepSizeMod   = 1.0-(linStep(rPos.y, vc_lowEdge, vc_highEdge)*0.97)*(timeNoon);
    vec3 dir            = mix(vec.light, vec.up, timeLightTransition);
        dir             = normalize(mat3(gbufferModelViewInverse)*dir);
    float stepSize      = (vc_thickness/steps)*stepSizeMod;
    vec3 rayStep        = dir*stepSize;

    rPos           += rayStep;
    
    float transmittance = 0.0;

    for (int i = 0; i<steps; i++) {
        if (rPos.y>vc_highEdge) continue;

        transmittance  += vc_shape(rPos);
        rPos           += rayStep;
    }
    return transmittance*density*stepSize;
}
float vc_getScatter(in float oD, in float lD, in float powder, in float phaseMod, in float lDmod, in float vDotL) {
    float transmittance = exp2(-lD*lDmod);
    float inscatter     = exp2(-oD*lDmod*3);
    float phase         = c_miePhase(vDotL*phaseMod)*0.93+0.07;
        phase           = mix(phase, 1.0, rainStrength*0.1);

    return max(powder*phase*transmittance, inscatter*0.004*(phase*0.5+0.5));
}

void vc_scatter(inout float scatter, in float oD, in vec3 rayPos, in float scatterCoeff, in float vDotL, in float transmittance, in float stepTransmittance) {
    float lD            = vc_lD(rayPos, 4)*0.3;
    float powder        = 1.0-exp2(-oD*2.0);
        powder          = mix(powder, 1.0, vDotL*0.4+0.6);
    float scatterInt    = scatterIntegral(stepTransmittance, 1.11);
    float beerPowderFake = 1.0-exp2(-oD*0.12)*0.5;

    float tempScatter   = vc_getScatter(oD, lD, powder*beerPowderFake, 1.0, 1.0, vDotL)*scatterCoeff*scatterInt*transmittance;

    scatter += tempScatter*transmittance*1.8;
}

void vc_multiscatter(inout float scatter, in float oD, in vec3 rayPos, in float scatterCoeff, in float vDotL, in float transmittance, in float stepTransmittance) {
    float tempScatter   = 0.0;
    float lD            = vc_lD(rayPos, 5)*1.1;
    float powder        = 1.0-exp2(-oD*2.0);
        powder          = mix(powder, 1.0, vDotL*0.4+0.6);
    float scatterInt    = scatterIntegral(stepTransmittance, 1.11);
    float beerPowderFake = 1.0-exp2(-oD*0.12)*0.5;
        
    for (int i = 0; i<2; i++) {

        float scatterMod = pow(0.5, float(i));
        float lDmod = pow(0.2, float(i));
        float phaseMod = pow(0.85, float(i));

        scatterCoeff *= scatterMod;

        tempScatter += vc_getScatter(oD, lD, powder*beerPowderFake, phaseMod, lDmod, vDotL)*scatterCoeff*scatterInt;
    }
    scatter += tempScatter*transmittance*1.8;
}