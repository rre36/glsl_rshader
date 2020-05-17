struct maskData {
    bool terrain;
    bool hand;
} mask;

struct materialData {
    float foliage;
    float emissive;
    float subsurface;
    bool beacon;
    bool unlit;
} mat;

struct pbrData {
    float roughness;
    float f0;
    float metallic;
} pbr;

void decodeData() {
    float maskData  = scene.sample3.r;
    float matData   = scene.sample3.g;

    vec3 pbrDecode  = vec3(decodeV2(scene.sample2.b), scene.sample3.b);

    mat.beacon      = unmap(matData, 0.92, 0.95)>0.5;
    mat.unlit       = unmap(matData, 0.96, 0.975)>0.5;
    
    mask.terrain    = (maskData > 0.125 || mat.beacon);
    mask.hand       = (maskData > 0.375 && maskData < 0.75);

    mat.foliage     = unmap(matData, 0.1, 0.5);
    mat.subsurface  = unmap(matData, 0.51, 0.70);
    mat.emissive    = unmap(matData, 0.71, 0.90);

    pbr.f0          = pbrDecode.x;
    pbr.roughness   = sqr(pbrDecode.y);
    pbr.metallic    = pbrDecode.z;
}