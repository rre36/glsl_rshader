uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferModelViewInverse;

//Temporal Reprojection based on Chocapic13's approach
vec2 taaReprojection(in vec2 coord, in float depth) {
    vec4 frag       = gbufferProjectionInverse*vec4(vec3(coord, depth)*2.0-1.0, 1.0);
        frag       /= frag.w;
        frag        = gbufferModelViewInverse*frag;

    vec4 prevPos    = frag + vec4(cameraPosition-previousCameraPosition, 0.0)*float(depth > 0.56);
        prevPos     = gbufferPreviousModelView*prevPos;
        prevPos     = gbufferPreviousProjection*prevPos;
    
    return prevPos.xy/prevPos.w*0.5+0.5;
}

void applyTAA(in float depth) {
    vec2 taaCoord       = taaReprojection(coord, depth);
    vec2 viewport       = 1.0/vec2(viewWidth, viewHeight);

    vec3 taaCol         = texture(colortex7, taaCoord).rgb;
        taaCol          = taaClamp(taaCol);

    vec3 coltl      = textureLod(colortex0,coord+vec2(-1.0,-1.0)*viewport,0).rgb;
	vec3 coltm      = textureLod(colortex0,coord+vec2( 0.0,-1.0)*viewport,0).rgb;
	vec3 coltr      = textureLod(colortex0,coord+vec2( 1.0,-1.0)*viewport,0).rgb;
	vec3 colml      = textureLod(colortex0,coord+vec2(-1.0, 0.0)*viewport,0).rgb;
	vec3 colmr      = textureLod(colortex0,coord+vec2( 1.0, 0.0)*viewport,0).rgb;
	vec3 colbl      = textureLod(colortex0,coord+vec2(-1.0, 1.0)*viewport,0).rgb;
	vec3 colbm      = textureLod(colortex0,coord+vec2( 0.0, 1.0)*viewport,0).rgb;
	vec3 colbr      = textureLod(colortex0,coord+vec2( 1.0, 1.0)*viewport,0).rgb;

	vec3 minCol = min(returnCol,min(min(min(coltl,coltm),min(coltr,colml)),min(min(colmr,colbl),min(colbm,colbr))));
	vec3 maxCol = max(returnCol,max(max(max(coltl,coltm),max(coltr,colml)),max(max(colmr,colbl),max(colbm,colbr))));

        taaCol      = clamp(taaCol, minCol, maxCol);

    float taaMix    = float(taaCoord.x>0.0 && taaCoord.x<1.0 && taaCoord.y>0.0 && taaCoord.y<1.0);

    vec2 velocity   = (coord-taaCoord)/viewport;

        if (depth == 1.0) taaMix *= clamp(1.0-sqrt(length(velocity))/1.999, 0.0, 1.0)*0.05+0.9;
        else taaMix     *= clamp(1.0-sqrt(length(velocity))/1.999, 0.0, 1.0)*0.35+0.6;

    returnTemporal  = taaClamp(mix(returnCol, taaCol, taaMix));

    //if (frameCounter<2) returnTemporal = vec3(returnCol);
}