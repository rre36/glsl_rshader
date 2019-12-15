flat out vec3 colSkylight;
flat out vec3 colSky;
flat out vec3 colHorizon;

uniform vec3 skyColor;
uniform vec3 fogColor;

void nature() {
    vec3 skyVanilla = pow(skyColor, vec3(2.2));
    vec3 fogVanilla = pow(fogColor, vec3(2.2));

    colSkylight = vec3(1.0, 0.6, 0.1);
    colSky      = skyVanilla;
    colHorizon  = fogVanilla;
}