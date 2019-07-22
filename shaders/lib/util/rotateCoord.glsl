vec2 rotateCoord(vec2 coord, float angle){
    float mid = 0.5;
    return vec2(
        cos(angle) * (coord.x - mid) + sin(angle) * (coord.y - mid) + mid,
        cos(angle) * (coord.y - mid) - sin(angle) * (coord.x - mid) + mid );
}
vec2 rotateCoord(vec2 coord, float angle, float mid){
    return vec2(
        cos(angle) * (coord.x - mid) + sin(angle) * (coord.y - mid) + mid,
        cos(angle) * (coord.y - mid) - sin(angle) * (coord.x - mid) + mid );
}