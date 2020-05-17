float rayleigh(float x) {
    return 3.0 / 4.0 * 1.0 / (4.0*pi)*(1.0 +sqr(x));
}
float mie(float x, float g) {
    float temp  = 1.0 + sqr(g) - 2.0*g*x;
    return (1.0 - sqr(g)) / ((4.0*pi) * temp*(temp*0.5+0.5));
}
vec2 getPhase(in float x, in float g) {
    float mie   = 1.0 + sqr(g) - 2.0*g*x;
        mie     = (1.0 - sqr(g)) / ((4.0*pi) * mie*(mie*0.5+0.5));

    float rayleigh = 8.0 / 10.0 * (7.0 / 5.0 + 1.0 / 2.0 * x);
        rayleigh  /= 4.0*pi;

    return vec2(mie, rayleigh);
}