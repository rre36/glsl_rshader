vec3 toLinear(vec3 x){
    vec3 temp = mix(x / 12.92, pow(.947867 * x + .0521327, vec3(2.4)), step(0.04045, x));
    return max(temp, 0.0);
}

vec3 toSRGB(vec3 x){
    return mix(x * 12.92, pow(x, vec3(1./2.4)) * 1.055 - 0.055, step(0.0031308, x));
}