vec3 getSky(in vec3 viewvec) {
    vec3 nFrag      = -viewvec;
    vec3 hVec       = normalize(-vec.up+nFrag);
    vec3 hVec2      = normalize(vec.up+nFrag);
    vec3 sgVec      = normalize(vec.sun+nFrag);
    vec3 mgVec      = normalize(vec.moon+nFrag);

    float hTop      = dot(hVec, nFrag);
    float hBottom   = dot(hVec2, nFrag);

    float horizonFade = linStep(hBottom, 0.3, 0.8);
        horizonFade = pow4(horizonFade)*0.85;

    float lowDome   = linStep(hBottom, 0.66, 0.71);
        lowDome     = pow3(lowDome);

    float horizonGrad = 1.0-max(hBottom, hTop);

    float horizon   = linStep(horizonGrad, 0.12, 0.31);
        horizon     = pow5(horizon)*0.8;

    float sunGrad   = 1.0-dot(sgVec, nFrag);
    float moonGrad  = 1.0-dot(mgVec, nFrag);

    float horizonGlow = saturate(pow2(sunGrad));
        horizonGlow = pow3(linStep(horizonGrad, 0.08-horizonGlow*0.1, 0.33-horizonGlow*0.05))*horizonGlow;
        horizonGlow = pow2(horizonGlow*1.3);
        horizonGlow = saturate(horizonGlow*0.75);

    float sunGlow   = linStep(sunGrad, 0.5, 0.98);
        sunGlow     = pow5(sunGlow);
        sunGlow    *= 1.0-timeNoon*0.5;

    float moonGlow  = pow(moonGrad*0.85, 15.0);
        moonGlow    = saturate(moonGlow*1.05)*0.8;

    vec3 sunColor   = colSunglow*2;
    vec3 sunLight   = colSunlight;
    vec3 moonColor  = vec3(0.55, 0.75, 1.0)*0.1;

    vec3 sky        = mix(colSky, colHorizon, horizonFade);
        sky         = mix(sky, colHorizon, horizon);
        sky         = mix(sky, colHorizon, lowDome);
        sky         = mix(sky, sunColor, saturate(sunGlow+horizonGlow)*(1.0-timeNight));
        sky         = mix(sky, moonColor, moonGlow*timeNight);

    return sky*3.0;
}