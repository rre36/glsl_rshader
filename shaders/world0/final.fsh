#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

#define INFO 0

#define setBitdepth 8       //[6 8 10 12]

#define setBrightness 1.0   //[0.5 0.6 0.7 0.8 0.9 1.0 1.02 1.1 1.2 1.3 1.4 1.5]
#define setContrast 1.0    //[0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 0.98 1.0 1.05 1.1 1.15 1.2 1.25 1.3]
#define setCurve 1.01       //[0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.90 0.92 0.94 0.96 0.98 1.0 1.02 1.04 1.06 1.08 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5]
#define setSaturation 1.02   //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.02 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]


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
        imageLuma = pow2(imageLuma)*expMax;
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

vec3 brightenContrast(vec3 x, const float brighten, const float contrast) {
    return (x - 0.5) * contrast + 0.5 + brighten;
}
vec3 curve(vec3 x, const float exponent) {
    return vec3(pow(abs(x.r), exponent),pow(abs(x.g), exponent),pow(abs(x.b), exponent));
}

void colorGrading() {
    scene.sdr     = curve(scene.sdr, setCurve);
    scene.sdr     = brightenContrast(scene.sdr, setBrightness-1.0, setContrast);
    float imageLuma = getLuma(scene.sdr);
    scene.sdr     = mix(vec3(imageLuma), scene.sdr, setSaturation);
    scene.sdr    *= vec3(1.0, 1.03, 1.0);
}

void main() {
    scene.hdr       = textureLod(colortex0, coord, 0).rgb;

/*    #ifdef MC_GL_RENDERER_GEFORCE
        scene.hdr  -= 1.0/255.0;
    #endif
*/
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

    colorGrading();

    imageDither();

    gl_FragColor = toVec4(scene.sdr);
}