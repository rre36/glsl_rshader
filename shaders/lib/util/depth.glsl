float depthLin(float depth) {
    return (2.0*near) / (far+near-depth * (far-near));
}
float depthLinInv(float depth) {
    return -((2.0*near / depth) - far-near)/(far-near);
}
float depthExp(float depth) {
    return (far * (depth-near)) / (depth * (far-near));
}