void diffuseLambert(in vec3 normal) {
    normal          = normalize(normal);
    vec3 light      = normalize(vec.light);
    float lambert   = dot(normal, light);
        lambert     = max(lambert, 0.0);
    sdata.diffuse   = saturate(mix(lambert, 1.0, mat.foliage*0.7));
}

void specGGX(in vec3 normal) {
    float roughness = pow2(pbr.roughness);
    #ifdef s_usePBR
        float F0        = pbr.f0;
    #else
        float F0        = 0.08;
        if (pbr.metallic>0.5) {
            F0          = 0.2;
        }
    #endif
    vec3 h          = vec.light - vec.view;
    float hn        = inversesqrt(dot(h, h));
    float dotLH     = saturate(dot(h,vec.light)*hn);
    float dotNH     = saturate(dot(h,normal)*hn);
    float dotNL     = saturate(dot(normal,vec.light));  
    float denom     = (dotNH * roughness - dotNH) * dotNH + 1.0;
    float D         = roughness / (pi * denom * denom);
    float F         = F0 + (1.0 - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
    float k2        = 0.25 * roughness;

    sdata.specular  = dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
    
    #ifndef s_usePBR
        sdata.specular *= pbr.f0;
    #endif
    
    sdata.specular *= 1.0-rainStrength;
}