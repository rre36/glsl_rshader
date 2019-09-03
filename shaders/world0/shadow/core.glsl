#include "/lib/shadow/warp.glsl"

float shadowFilter(in sampler2DShadow shadowtex, in vec3 wPos) {
    const float step = 1.0/shadowMapResolution;
    float noise     = ditherGradNoise()*pi;
    vec2 offset     = vec2(cos(noise), sin(noise))*step;
    float shade     = shadow2D(shadowtex, vec3(wPos.xy+offset, wPos.z)).x;
        shade      += shadow2D(shadowtex, vec3(wPos.xy-offset, wPos.z)).x;
        shade      += shadow2D(shadowtex, wPos.xyz).x*0.5;
    return shade*0.4;
}
vec4 shadowFilterCol(in sampler2DShadow shadowtex, in vec3 wPos) {
    const float step = 1.0/shadowMapResolution;
    float noise     = ditherGradNoise()*pi;
    vec2 offset     = vec2(cos(noise), sin(noise))*step;
    vec4 shade     = shadow2D(shadowtex, vec3(wPos.xy+offset, wPos.z));
        shade      += shadow2D(shadowtex, vec3(wPos.xy-offset, wPos.z));
        shade      += shadow2D(shadowtex, wPos.xyz)*0.5;
    return shade*0.4;
}

vec3 getShadowCoordinate2D(in vec3 screenpos, in float bias, out float distortion) {
	vec3 position 	= screenpos;
		position   += vec3(bias)*vec.light;
		position 	= viewMAD(gbufferModelViewInverse, position);
		position 	= viewMAD(shadowModelView, position);
		position 	= projMAD(shadowProjection, position);
		position.z *= 0.2;

    distortion      = 1.0;
    warpShadowmap(position.xy, distortion);

	return position*0.5+0.5;
}

#ifndef shadowBias
    #define shadowBias 0.08
#endif

void getDirectLight(bool diffuseLit) {
    float bias          = shadowBias*(3072.0/shadowMapResolution);
    float distortion    = 0.0;
    vec3 viewpos        = pos.view;

    #ifdef temporalAA
        viewpos = getViewpos(depth.depth, taaJitter(gl_FragCoord.xy/vec2(viewWidth, viewHeight), -0.5));
    #endif

    vec3 scoord         = getShadowCoordinate2D(pos.view, bias, distortion);

    float shade         = 1.0;
    vec4 shadowcol      = vec4(1.0);
    bool translucencyShadow = false;

    if (diffuseLit) {
        shade       = shadowFilter(shadowtex1, scoord);
        shadowcol   = shadowFilterCol(shadowcolor0, scoord);

        float temp1 = shadowFilter(shadowtex0, scoord);

        translucencyShadow = temp1<shade;
    }

    sdata.shadow    = shade;
    sdata.shadowcolor = translucencyShadow ? mix(vec3(1.0), shadowcol.rgb, shadowcol.a) : vec3(1.0);
}