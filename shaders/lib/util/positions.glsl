vec3 screenSpacePos(float depth) {
    vec4 posNDC = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
        posNDC  = gbufferProjectionInverse*posNDC;
    return posNDC.xyz/posNDC.w;
}
vec3 screenSpacePos(float depth, vec2 coord) {
    vec4 posNDC = vec4(coord.x*2.0-1.0, coord.y*2.0-1.0, 2.0*depth-1.0, 1.0);
        posNDC  = gbufferProjectionInverse*posNDC;
    return posNDC.xyz/posNDC.w;
}

vec3 worldSpacePos(float depth) {
    vec3 posCamSpace = screenSpacePos(depth).xyz;
    vec3 posWorldSpace = viewMAD(gbufferModelViewInverse, posCamSpace);
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}
vec3 worldSpacePos(float depth, vec2 coord) {
    vec3 posCamSpace = screenSpacePos(depth, coord).xyz;
    vec3 posWorldSpace = viewMAD(gbufferModelViewInverse, posCamSpace);
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace;
}

vec3 toWorldSpace(vec3 screenPos) {
    vec3 posCamSpace = screenPos;
    vec3 posWorldSpace = viewMAD(gbufferModelViewInverse, posCamSpace);
    posWorldSpace.xyz += cameraPosition.xyz;
    return posWorldSpace.xyz;
}