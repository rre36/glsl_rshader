vec3 bloomExpand(vec3 x) {
    return x * x * x * x * 32.0;
}
void bloom() {
    vec3 blur1 = bloomExpand(texture(colortex4,coord.xy/pow(2.0,2.0) + vec2(0.0,0.0)).rgb);
    vec3 blur2 = bloomExpand(texture(colortex4,coord.xy/pow(2.0,3.0) + vec2(0.3,0.0)).rgb)*0.9;
    vec3 blur3 = bloomExpand(texture(colortex4,coord.xy/pow(2.0,4.0) + vec2(0.0,0.3)).rgb)*0.85;
    vec3 blur4 = bloomExpand(texture(colortex4,coord.xy/pow(2.0,5.0) + vec2(0.1,0.3)).rgb)*0.75;
    vec3 blur5 = bloomExpand(texture(colortex4,coord.xy/pow(2.0,6.0) + vec2(0.2,0.3)).rgb)*0.66;
    vec3 blur6 = bloomExpand(texture(colortex4,coord.xy/pow(2.0,7.0) + vec2(0.3,0.3)).rgb)*0.5;
    vec3 blur7 = bloomExpand(texture(colortex4,coord.xy/pow(2.0,8.0) + vec2(0.4,0.3)).rgb)*0.25;
	
    vec3 blur = (blur1 + blur2 + blur3 + blur4 + blur5 + blur6 + blur7)*bloomIntensity*(1.0+rainStrength*0.5);

    returnCol += blur/7.0;
}