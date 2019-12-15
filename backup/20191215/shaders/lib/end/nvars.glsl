flat out vec3 colSunlight;
flat out vec3 colSkylight;
flat out vec3 colSky;
flat out vec3 colHorizon;

uniform vec3 skyColor;
uniform vec3 fogColor;

void nature() {
    vec3 skyVanilla = pow(skyColor, vec3(2.2));
    vec3 fogVanilla = pow(fogColor, vec3(2.2));

    colSunlight = vec3(0.8, 0.4, 1.0);
    colSkylight = vec3(0.7, 0.4, 1.0);
    colSky      = skyVanilla;
    colHorizon  = fogVanilla;
}