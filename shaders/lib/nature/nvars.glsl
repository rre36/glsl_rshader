flat out vec3 colSunlight;
flat out vec3 colSkylight;
flat out vec3 colSky;
flat out vec3 colHorizon;
flat out vec3 colSunglow;
flat out vec2 fogDensity;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform float rainStrength;
uniform float wetness;

const float wetnessHalflife = 60.0;
const float drynessHalflife = 150.0;

void nature() {
    vec3 sunlightSunrise;
        sunlightSunrise.r = 1.0;
        sunlightSunrise.g = 0.48;
        sunlightSunrise.b = 0.0;
        sunlightSunrise *= 0.8;

    vec3 sunlightNoon;
        sunlightNoon.r = 1.0;
        sunlightNoon.g = 1.0;
        sunlightNoon.b = 1.0;
        sunlightNoon *= 1.2;

    vec3 sunlightSunset;
        sunlightSunset.r = 1.0;
        sunlightSunset.g = 0.4;
        sunlightSunset.b = 0.0;
        sunlightSunset *= 0.6;

    vec3 sunlightNight;
        sunlightNight.r = 0.0;
        sunlightNight.g = 0.7;
        sunlightNight.b = 1.0;
        sunlightNight *= 0.05;

    colSunlight = sunlightSunrise*timeSunrise + sunlightNoon*timeNoon + sunlightSunset*timeSunset + sunlightNight*timeNight;

    vec3 skylightSunrise;
        skylightSunrise.r = 1.0;
        skylightSunrise.g = 0.7;
        skylightSunrise.b = 0.3;
        skylightSunrise *= 0.6;

    vec3 skylightNoon;
        skylightNoon.r = 1.0;
        skylightNoon.g = 1.0;
        skylightNoon.b = 1.0;
        skylightNoon *= 1.0;

    vec3 skylightSunset;
        skylightSunset.r = 1.0;
        skylightSunset.g = 0.6;
        skylightSunset.b = 0.2;
        skylightSunset *= 0.5;

    vec3 skylightNight;
        skylightNight.r = 0.0;
        skylightNight.g = 0.7;
        skylightNight.b = 1.0;
        skylightNight *= 0.25;

    colSkylight = skylightSunrise*timeSunrise + skylightNoon*timeNoon + skylightSunset*timeSunset + skylightNight*timeNight;
    colSkylight *= 1-timeMoon*0.6;

    vec3 skyVanilla = pow(skyColor, vec3(2.2));

    vec3 skySunrise;
        skySunrise.r = 0.15;
        skySunrise.g = 0.46;
        skySunrise.b = 1.0;
        skySunrise *= 0.2;

    vec3 skyNoon;
        skyNoon.r = 0.0;
        skyNoon.g = 0.53;
        skyNoon.b = 1.0;
        skyNoon *= 0.5;

    vec3 skySunset;
        skySunset.r = 0.1;
        skySunset.g = 0.25;
        skySunset.b = 1.0;
        skySunset *= 0.24;

    vec3 skyNight;
        skyNight.r = 0.0;
        skyNight.g = 0.35;
        skyNight.b = 1.0;
        skyNight *= 0.01;

    colSky = skySunrise*timeSunrise + skyNoon*timeNoon + skySunset*timeSunset + skyNight*timeNight;
    colSky *= (1-timeMoon*0.7);
    colSky = mix(colSky, vec3(vec3avg(colSky)), rainStrength*0.92);

    vec3 horizonSunrise;
        horizonSunrise.r = 1.0;
        horizonSunrise.g = 0.28;
        horizonSunrise.b = 0.44;
        horizonSunrise *= 0.9;

    vec3 horizonNoon;
        horizonNoon.r = 0.37;
        horizonNoon.g = 0.71;
        horizonNoon.b = 1.00;
        horizonNoon *= 1.4;

    vec3 horizonSunset;
        horizonSunset.r = 1.0;
        horizonSunset.g = 0.42;
        horizonSunset.b = 0.9;
        horizonSunset *= 1.2;

    vec3 horizonNight;
        horizonNight.r = 0.08;
        horizonNight.g = 0.5;
        horizonNight.b = 1.0;
        horizonNight *= 0.06;

    colHorizon = horizonSunrise*timeSunrise + horizonNoon*timeNoon + horizonSunset*timeSunset + horizonNight*timeNight;
    colHorizon *= (1-timeMoon*0.89);
    colHorizon = mix(colHorizon, vec3(vec3avg(colHorizon)), rainStrength*0.8);

    vec3 sunglowSunrise;
        sunglowSunrise.r = 1.0;
        sunglowSunrise.g = 0.3;
        sunglowSunrise.b = 0.05;
        sunglowSunrise *= 1.2;

    vec3 sunglowNoon;
        sunglowNoon.r = 1.0;
        sunglowNoon.g = 1.0;
        sunglowNoon.b = 1.0;
        sunglowNoon *= 0.9;

    vec3 sunglowSunset;
        sunglowSunset.r = 1.0;
        sunglowSunset.g = 0.3;
        sunglowSunset.b = 0.2;
        sunglowSunset *= 1.2;

    vec3 sunglowNight;
        sunglowNight.r = 0.0;
        sunglowNight.g = 0.6;
        sunglowNight.b = 1.0;
        sunglowNight *= 0.004;

    colSunglow = sunglowSunrise*timeSunrise + sunglowNoon*timeNoon + sunglowSunset*timeSunset + sunlightNight*timeNight;
    colSunglow = mix(colSunglow, vec3(vec3avg(colSunglow)), rainStrength*0.5);

    fogDensity  = vec2(0.45, 2.0);
}