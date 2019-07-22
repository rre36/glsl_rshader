#define SIGMA 10.0
#define MSIZE 15

float normpdf(in float x, in float sigma){
	return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
}
float normpdf2(in vec2 v, in float sigma){
	return 0.39894*exp(-0.5*dot(v,v)/(sigma*sigma))/sigma;
}
float normpdf3(in vec3 v, in float sigma){
	return 0.39894*exp(-0.5*dot(v,v)/(sigma*sigma))/sigma;
}
float normpdf3(in vec4 v, in float sigma){
	return 0.39894*exp(-0.5*dot(v,v)/(sigma*sigma))/sigma;
}
/*
vec3 bilateralProcedural(sampler2D tex, const float sigma) {
	//declare stuff
	const int kSize = (MSIZE-1)/2;
	float kernel[MSIZE];
	vec3 final_colour = vec3(0.0);
	//create the 1-D kernel
	float Z = 0.0;
	
	for (int j = 0; j <= kSize; ++j) {
		kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), SIGMA);
	}
	
    vec3 c = texture(tex, (gl_FragCoord.xy / vec2(viewWidth, viewHeight))).rgb;
	vec3 cc;
	float factor;
	float bZ = 1.0/normpdf(0.0, sigma);
	//read out the texels
	for (int i=-kSize; i <= kSize; ++i) {

		for (int j=-kSize; j <= kSize; ++j) {
			cc = texture(tex, (gl_FragCoord.xy+vec2(float(i),float(j))) / vec2(viewWidth, viewHeight)).rgb;
			factor = normpdf3(cc-c, sigma)*bZ*kernel[kSize+j]*kernel[kSize+i];
			Z += factor;
			final_colour += factor*cc;
		}
	}
		
	return max(vec3(final_colour/Z), 0.0);
}
*/
const float kernel15[15] = float[15](
	0.031225216, 
	0.033322271, 
	0.035206333, 
	0.036826804, 
	0.038138565, 
	0.039104044, 
	0.039695028, 
	0.039894000,
	0.039695028, 
	0.039104044, 
	0.038138565, 
	0.036826804, 
	0.035206333, 
	0.033322271, 
	0.031225216
);

float bilateral15f(sampler2D tex, const float sigma, const int steps, const float mip) {
	float result 	= (0.0);

	#ifndef bilateralChannel
		#define bilateralChannel 0
	#endif

	#if bilateralChannel == 0
	float color 	= textureLod(tex, coord, mip).r;
	#elif bilateralChannel == 1
	float color 	= textureLod(tex, coord, mip).g;
	#elif bilateralChannel == 2
	float color 	= textureLod(tex, coord, mip).b;
	#elif bilateralChannel == 3
	float color 	= textureLod(tex, coord, mip).a;
	#endif

    vec2 pixelRad 	= 1.0/vec2(viewWidth, viewHeight);

	float sampleC 	= (0.0);
	float resultWeight = 0.0;
	float temp 		= 1.0/normpdf(0.0, sigma);
	//const int steps = 8;

	for (int i = -steps; i<=steps; i++) {
		for (int j = -steps; j<=steps; j++) {

			#if bilateralChannel == 0
			sampleC 	= textureLod(tex, coord+vec2(float(i), float(j))*pixelRad, mip).r;
			#elif bilateralChannel == 1
			sampleC 	= textureLod(tex, coord+vec2(float(i), float(j))*pixelRad, mip).g;
			#elif bilateralChannel == 2
			sampleC 	= textureLod(tex, coord+vec2(float(i), float(j))*pixelRad, mip).b;
			#elif bilateralChannel == 3
			sampleC 	= textureLod(tex, coord+vec2(float(i), float(j))*pixelRad, mip).a;
			#endif

			float weight = normpdf(sampleC-color, sigma)*temp*kernel15[i]*kernel15[j];
			resultWeight += weight;
			result += sampleC*weight;
		}
	}
	return max(result/resultWeight, 0.0);
}
vec3 bilateral15(sampler2D tex, const float sigma, const int steps, const float mip) {
	vec3 result 	= vec3(0.0);
	vec3 color 	    = textureLod(tex, coord, mip).rgb;
    vec2 pixelRad 	= 1.0/vec2(viewWidth, viewHeight);

	vec3 sampleC 	= vec3(0.0);
	float resultWeight = 0.0;
	float temp 		= 1.0/normpdf(0.0, sigma);
	//const int steps = 4;

	for (int i = -steps; i<=steps; i++) {
		for (int j = -steps; j<=steps; j++) {
			sampleC 	= textureLod(tex, coord+vec2(float(i), float(j))*pixelRad, mip).rgb;
			float weight = normpdf3(sampleC-color, sigma)*temp*kernel15[7+i]*kernel15[7+j];
			resultWeight += weight;
			result += sampleC*weight;
		}
	}
	return max(result/resultWeight, 0.0);
}

vec4 bilateral15rgba(sampler2D tex, const float sigma, const int steps, const float mip) {
	vec4 result 	= vec4(0.0);
	vec4 color 	    = textureLod(tex, coord, mip);
    vec2 pixelRad 	= 1.0/vec2(viewWidth, viewHeight);

	vec4 sampleC 	= vec4(0.0);
	vec4 resultWeight = vec4(0.0);
	float temp 		= 1.0/normpdf(0.0, sigma);
	//const int steps = 4;

	for (int i = -steps; i<=steps; i++) {
		for (int j = -steps; j<=steps; j++) {

			sampleC 	= textureLod(tex, coord+vec2(float(i), float(j))*pixelRad, mip);

			float tempW = temp*kernel15[7+i]*kernel15[7+j];

			float weightCol = normpdf3(sampleC.rgb-color.rgb, sigma)*tempW;
			float weightAlpha = normpdf(sampleC.a-color.a, sigma)*tempW;

			resultWeight.rgb += weightCol;
			resultWeight.a   += weightAlpha;

			result += sampleC*vec4(vec3(weightCol), weightAlpha);
		}
	}
	return max(result/resultWeight, 0.0);
}

/*
float depthLin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}
vec4 bilateral15rgbaDepth(sampler2D tex, const float sigma, const int steps, const float mip, sampler2D depthtex) {
	vec4 result 	= vec4(0.0);
	vec4 color 	    = textureLod(tex, coord, mip);
	float depth 	= (texture(depthtex, coord).x);
    vec2 pixelRad 	= 1.0/vec2(viewWidth, viewHeight);

	vec4 sampleC 	= vec4(0.0);
	float sampleZ 	= 0.0;
	vec4 resultWeight = vec4(0.0);
	float temp 		= 1.0/normpdf(0.0, sigma);
	//const int steps = 4;

	for (int i = -steps; i<=steps; i++) {
		for (int j = -steps; j<=steps; j++) {

			sampleC 	= textureLod(tex, coord+vec2(float(i), float(j))*pixelRad, mip);
			sampleZ 	= (texture(depthtex, coord+vec2(float(i), float(j))*pixelRad).x);

			float tempW = temp*kernel15[7+i]*kernel15[7+j];

			//float weightCol = normpdf3(sampleC.rgb-color.rgb, sigma)*tempW;
			//float weightAlpha = normpdf(sampleC.a-color.a, sigma)*tempW;
			float weight 	= normpdf((sampleZ-depth)*4.0, sigma)*tempW; 

			resultWeight.rgb += weight;
			resultWeight.a   += weight;

			result += sampleC*vec4(vec3(weight), weight);
		}
	}
	return max(result/resultWeight, 0.0);
}*/