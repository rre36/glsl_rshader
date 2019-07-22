/*
Metal mapping index, all in integers
050 Iron
060 Gold
070 Aluminum
080 Chrome
090 Copper
100 Lead
110 Platinum
120 Silver

>220 Generic
*/

float integerLinStep(in float x, const int low, const int high) {
    int data = int(x*255.0);
    int mapped = clamp((data-low)/(high-low), 0, 255);

    return float(mapped/255.0);
}
int bitmask(in float x, const int bit) {
    int data = int(x*255.0);
    if (data == bit) return 1;
    else return 0;
}
float remapMetals(in int f0) {
    if(f0==230) {
        //iron
        return 50/255.0;
    } else if (f0==231) {
        //gold
        return 60/255.0;
    } else if (f0==232) {
        //aluminum
        return 70/255.0;
    } else if (f0==233) {
        //chrome
        return 80/255.0;
    } else if (f0==234) {
        //copper
        return 90/255.0;
    } else if (f0==235) {
        //lead
        return 100/255.0;
    } else if (f0==236) {
        //platinum
        return 110/255.0;
    } else if (f0==237) {
        //silver
        return 120/255.0;
    } else if (f0>230) {
        return 1.0;
    } else {
        return 0.0;
    }

}

void getLabNormal() {
    vec3 texnormal      = normalSample;
        texnormal       = texnormal*2.0-(254.0/255.0);

        #ifdef s_usePBR
            pbr.ao          = pow2(length(texnormal));
        #endif

        texnormal       = normalize(texnormal);
        
        texnormal       = flattenNormal(texnormal);

    mat3 tbnMatrix = mat3(tangent.x, binormal.x, nrm.x,
				tangent.y, binormal.y, nrm.y,
				tangent.z, binormal.z, nrm.z);

    normal  = normalize(texnormal*tbnMatrix);
}

void getLabPbr() {
    vec4 texsample  = pbrSample;
    pbr.roughness   = 1.0-texsample.r;
    pbr.roughness   = max(pbr.roughness, 0.02);
    pbr.f0          = pow2(clamp(texsample.g, 0.0, 229.0/255.0));
    pbr.porosity    = int(texsample.b*255.0)<65 ? integerLinStep(texsample.b, 0, 64) : 0.0;

    #ifdef s_useTexEmission
        pbr.emission    = int(texsample.a*255.0)<255 ? texsample.a : 0.0;
        emissiveTex    += pbr.emission;
    #endif

    roughness       = pbr.roughness;
    metalness       = float(int(texsample.g*255.0) >= 230);
    specularity     = pbr.f0;

    #if (defined s_useNormal && defined s_useTexAO)
        ao *= saturate(pbr.ao);
    #endif
}