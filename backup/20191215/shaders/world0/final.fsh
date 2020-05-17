#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

#define INFO 0

#define setBitdepth 8       //[6 8 10 12]

const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex7;

uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

in vec2 coord;

flat in float timeNight;
flat in float timeMoon;

#include "/lib/util/colorConversion.glsl"

struct sceneData{
    vec3 hdr;
    vec3 sdr;
    float exposure;
} scene;


void autoExposureAdvanced() {
	float imageLuma = texture(colortex7, coord).a;
	imageLuma       = clamp((imageLuma), expMinimum, expMaximum);

	scene.exposure  = 1.0 - exp(-1.0/imageLuma);
}
void autoExposureNonTemporal() {
	float imageLuma = getLuma(textureLod(colortex0, vec2(0.5), ceil(log2(max(viewHeight, viewWidth)))).rgb);
	imageLuma       = clamp(imageLuma, expMinimum, expMaximum);

	scene.exposure  = 1.0 - exp(-1.0/imageLuma);
}
void autoExposureLegacy() {
    const float expMax  = 2.0;
    const float expMin  = expMinimum;
    float eyeSkylight = eyeBrightnessSmooth.y*(1-timeNight*0.3-timeMoon*0.3);
    float eyeLight = eyeBrightnessSmooth.x*0.7;
    float imageLuma = max(eyeSkylight, eyeLight);
        imageLuma /= 240.0;
        imageLuma = sqr(imageLuma)*expMax;
        imageLuma = clamp(imageLuma, expMin, expMax); 
    scene.exposure = 1.0 - exp(-1.0/imageLuma);
}
void fixedExposure() {
    float exposure = expManual;
    scene.exposure = 1.0 - exp(-1.0/exposure);
}

void noTonemap() {
    scene.sdr   = scene.hdr*scene.exposure;
    scene.sdr   = toSRGB(scene.sdr);
}

/*
void reinhardTonemap() {    //naive reinhard implemetation
    scene.sdr   = scene.hdr*scene.exposure;
    //scene.sdr   = scene.sdr/(1.0+scene.sdr);
    scene.sdr   = toSRGB(scene.sdr);
}
*/
void reinhardTonemap(){     //based off jodie's approach
    scene.sdr   = scene.hdr*scene.exposure;
    float luma  = dot(scene.sdr, vec3(0.2126, 0.7152, 0.0722));
    vec3 color  = scene.sdr/(scene.sdr + 1.0);
    scene.sdr   = mix(scene.sdr/(luma + 1.0), color , color);
    scene.sdr   = toSRGB(scene.sdr);
}

#include "/lib/util/dither.glsl"

int getColorBit() {
	if (setBitdepth==1) {
		return 1;
	} else if (setBitdepth==2) {
		return 4;
	} else if (setBitdepth==4) {
		return 16;
	} else if (setBitdepth==6) {
		return 64;
	} else if(setBitdepth==8){
		return 255;
	} else if (setBitdepth==10) {
		return 1023;
	} else {
		return 255;
	}
}

void imageDither() {
    int bits = getColorBit();
    vec3 colDither = scene.sdr;
        colDither *= bits;
        colDither += bayer64(gl_FragCoord.xy)-0.5;

        float colR = round(colDither.r);
        float colG = round(colDither.g);
        float colB = round(colDither.b);

    scene.sdr = vec3(colR, colG, colB)/bits;
}

void main() {
    scene.hdr       = textureLod(colortex0, coord, 0).rgb;
    scene.sdr       = scene.hdr;
    scene.exposure  = 1.0;

    #if expMethod==0
        autoExposureAdvanced();
    #elif expMethod==1
        autoExposureNonTemporal();
    #elif expMethod==2
        autoExposureLegacy();
    #elif expMethod==3
        fixedExposure();
    #endif

    reinhardTonemap();

    imageDither();

    gl_FragColor = toVec4(scene.sdr);
}