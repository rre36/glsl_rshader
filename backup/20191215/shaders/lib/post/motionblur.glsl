#define mBlurSamples 8  //[3 6 7 8 9 12 15 18 21]
#define mBlurInt 1.0    //[0.5 0.75 1.0 1.25 1.5 1.75 2.0]

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferModelViewInverse;

void motionblur() {
    const int samples = mBlurSamples;
    const float blurStrength = 0.018*mBlurInt;

    float d     = depth;
        d       = mix(d, pow(d, 0.01), mask.hand);
    float dither = ditherStatic;
    vec2 viewport = 2.0/vec2(viewWidth, viewHeight);

    vec4 currPos = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*d-1.0, 1.0);

    vec4 frag   = gbufferProjectionInverse*currPos;
        frag    = gbufferModelViewInverse*frag;
        frag   /= frag.w;
        frag.xyz += cameraPosition;

    vec4 prevPos = frag;
        prevPos.xyz -= previousCameraPosition;
        prevPos = gbufferPreviousModelView*prevPos;
        prevPos = gbufferPreviousProjection*prevPos;
        prevPos /= prevPos.w;

    float blurSize = blurStrength;
        blurSize /= frameTime*30;
        blurSize  = min(blurSize, 0.033);

    vec2 vel    = (currPos-prevPos).xy;
        vel    *= blurSize;
    const float maxVel = 0.046;
        vel     = clamp(vel, -maxVel, maxVel);
        vel     = vel - (vel/2.0);

    vec2 mCoord  = coord;
    vec3 colBlur = vec3(0.0);
    mCoord += vel*dither;

    int fix = 0;

    for (int i = 0; i<samples; i++, mCoord +=vel) {
        if (mCoord.x>=1.0 || mCoord.y>=1.0 || mCoord.x<=0.0 || mCoord.y<=0.0) {
            colBlur += textureLod(colortex0, coord, 0).rgb;
            fix += 1;
            break;
        } else {
            vec2 coordB = clamp(mCoord, viewport, 1.0-viewport);
            colBlur += textureLod(colortex0, coordB, 0).rgb;
            ++fix;
        }
    }
    colBlur /= fix;
    returnCol = colBlur;
}