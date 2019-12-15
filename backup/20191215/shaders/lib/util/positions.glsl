//viewspace pos
vec3 getViewpos(float depth) {
    vec4 posNDC = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
        posNDC  = gbufferProjectionInverse*posNDC;
    return posNDC.xyz/posNDC.w;
}
vec3 getViewpos(float depth, vec2 coord) {
    vec4 posNDC = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
        posNDC  = gbufferProjectionInverse*posNDC;
    return posNDC.xyz/posNDC.w;
}

//worldspace pos
vec3 getWorldpos(float depth) {
    vec3 posCamSpace    = getViewpos(depth);
    vec3 posWorldSpace  = viewMAD(gbufferModelViewInverse, posCamSpace);
    posWorldSpace      += cameraPosition;
    return posWorldSpace;
}
vec3 getWorldpos(float depth, vec2 coord) {
    vec3 posCamSpace    = getViewpos(depth, coord);
    vec3 posWorldSpace  = viewMAD(gbufferModelViewInverse, posCamSpace);
    posWorldSpace      += cameraPosition;
    return posWorldSpace;
}

//vice-versa conversions
vec3 toWorldpos(vec3 screenPos) {
    vec3 posCamSpace    = screenPos;
    vec3 posWorldSpace  = viewMAD(gbufferModelViewInverse, posCamSpace);
    posWorldSpace      += cameraPosition;
    return posWorldSpace;
}
vec3 toViewpos(vec3 worldpos) {
    vec3 posWorldSpace  = worldpos;
    posWorldSpace      -= cameraPosition;
    vec3 posCamSpace    = viewMAD(gbufferModelView, posWorldSpace);
    return posCamSpace;
}