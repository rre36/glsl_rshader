mat2x3 getMetalIOR(in int metal) {
    if (metal==50) {
        //iron
        const vec3 n = vec3(2.9114, 2.9497, 2.5845);
        const vec3 k = vec3(3.0893, 2.9318, 2.7670);
        return mat2x3(n, k);
    } else if (metal==60) {
        //gold
        const vec3 n = vec3(0.18299, 0.42108, 1.3734);
        const vec3 k = vec3(3.4242, 2.3459, 1.7704);
        return mat2x3(n, k);
    } else if (metal==70) {
        //aluminum
        const vec3 n = vec3(1.3456, 0.96521, 0.61722);
        const vec3 k = vec3(7.4746, 6.3995, 5.3031);
        return mat2x3(n, k);
    } else if (metal==80) {
        //chrome
        const vec3 n = vec3(3.1071, 3.1812, 2.3230);
        const vec3 k = vec3(3.3314, 3.3291, 3.1350);
        return mat2x3(n, k);
    } else if (metal==90) {
        //copper
        const vec3 n = vec3(0.27105, 0.67693, 1.3164);
        const vec3 k = vec3(3.6092, 2.6248, 2.2921);
        return mat2x3(n, k);
    } else if (metal==100) {
        //lead
        const vec3 n = vec3(1.9100, 1.8300, 1.4400);
        const vec3 k = vec3(3.5100, 3.4000, 3.1800);
        return mat2x3(n, k);
    } else if (metal==110) {
        //platinum
        const vec3 n = vec3(2.3757, 2.0847, 1.8453);
        const vec3 k = vec3(4.2655, 3.7153, 3.1365);
        return mat2x3(n, k);
    } else if (metal==120) {
        //silver
        const vec3 n = vec3(0.15943, 0.14512, 0.13547);
        const vec3 k = vec3(3.9291, 3.1900, 2.3808);
        return mat2x3(n, k);
    } else {
        return mat2x3(vec3(0.0), vec3(0.0));
    }
}

vec3 getComplexFresnel(in vec3 n, in vec3 k) {
    float vDotL = saturate(dot(scene.normal, -vec.view));

    vec3 K    = k*k;
    vec3 NK   = n*n + K;

    vec3 CN     = (vDotL*2.0)*n;
    vec3 C      = vec3(pow2(vDotL));

    vec3 rsN    = NK-CN+C;
    vec3 rsD    = NK+CN+C;
    vec3 rs     = rsN/rsD;

    vec3 rpN    = NK*C - CN + 1.0;
    vec3 rpD    = NK*C + CN + 1.0;
    vec3 rp     = rpN/rpD;

    return saturate(0.5*(rs+rp));
}