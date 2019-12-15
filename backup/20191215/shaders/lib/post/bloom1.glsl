vec3 bloomBuffers(float mip, vec2 offset){
	vec3 bufferTex 	= vec3(0.0);
	vec3 temp 		= vec3(0.0);
	float scale 	= pow(2.0, mip);
	vec2 bCoord 	= (coord-offset)*scale;
	float padding 	= 0.005*scale;

	if (bCoord.x>-padding && bCoord.y>-padding && bCoord.x<1.0+padding && bCoord.y<1.0+padding) {
		for (int i=0;  i<7; i++) {
			for (int j=0; j<7; j++) {
				float wg 	= clamp(1.0-length(vec2(i-3,j-3))*0.28, 0.0, 1.0);
					wg 		= pow(wg, 2.0)*20;
				vec2 tCoord = (coord-offset+vec2(i-3, j-3)*pxWidth*vec2(1.0, aspectRatio))*scale;
				if (wg>0) {
					temp 			= ((texture(colortex0, tCoord).rgb)-(bloomThreshold*(1.0/mip)))*wg;
						bufferTex  += max(temp, 0.0);
				}
			}
		}
	bufferTex /=49;
	}
return pow(bufferTex/32.0, vec3(0.2));
}

void makeBloomBuffer(inout vec3 blur) {
	blur += bloomBuffers(2,vec2(0,0));
	blur += bloomBuffers(3,vec2(0.3,0));
	blur += bloomBuffers(4,vec2(0,0.3));
	blur += bloomBuffers(5,vec2(0.1,0.3));
	blur += bloomBuffers(6,vec2(0.2,0.3));
	blur += bloomBuffers(7,vec2(0.3,0.3));
	blur += bloomBuffers(8,vec2(0.4,0.3));
	blur += bloomBuffers(9,vec2(0.5,0.3));
}