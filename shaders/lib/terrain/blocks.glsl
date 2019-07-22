flat out float foliage;
flat out float emissive;
flat out int metal;
flat out int subsurface;
flat out int gem;
flat out int lava;
flat out int snow;

bool isTopVertex;
bool blockWindGround;
bool blockWindDoubleLow;
bool blockWindDoubleHigh;
bool blockWindFree;
bool blockEmissive;
bool blockWindFire;
bool blockMetallic;
bool blockSubsurface;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

struct blockIdStruct {
    int tallgrass;
    int sapling;
    int shrub;
    int wheat;
    int carrot;
    int potato;
    int beets;
    int leaves;
    int leaves2;
    int vine;
    int reed;
    int doublegrass;
    int torch;
    int lava;
    int lavaFlow;
    int glowstone;
    int seaLantern;
    int water;
    int fire;
    int gold;
    int iron;
    int diamond;
    int emerald;
    int redstone;
    int anvil;
    int glassStain;
    int dandelion;
    int poppy;
    int genericCrop;
    int genericGrass;
    int genericMetal;
    int snow;
} block;

void idSetup() {
    block.tallgrass=31;
    block.sapling=6;
    block.shrub=32;
    block.wheat=59;
    block.carrot=141;
    block.potato=142;
    block.beets=207;
    block.leaves=18;
    block.leaves2=161;
    block.vine=106;
    block.reed=83;
    block.doublegrass=175;
    block.torch=50;
    block.glowstone=89;
    block.lava=10;
    block.lavaFlow=11;
    block.seaLantern=169;
    block.water=999;
    block.fire=51;
    block.gold=41;
    block.iron=42;
    block.diamond=57;
    block.emerald=133;
    block.redstone=152;
    block.anvil=145;
    block.glassStain=95;
    block.dandelion=37;
    block.poppy=38;
    block.genericCrop=600;
    block.genericGrass=601;
    block.genericMetal=602;
    block.snow=302;

    isTopVertex = (gl_MultiTexCoord0.t < mc_midTexCoord.t);

    blockWindGround = (mc_Entity.x == block.tallgrass ||
     mc_Entity.x == block.sapling ||
     mc_Entity.x == block.shrub ||
     mc_Entity.x == block.wheat ||
     mc_Entity.x == block.carrot ||
     mc_Entity.x == block.potato ||
     mc_Entity.x == block.beets ||
     mc_Entity.x == block.dandelion ||
     mc_Entity.x == block.poppy ||
     mc_Entity.x == block.genericCrop ||
     mc_Entity.x == block.genericGrass);

    blockWindDoubleLow = mc_Entity.x == 240;
    blockWindDoubleHigh = mc_Entity.x == 241;

    blockWindFree = (mc_Entity.x == block.leaves ||
     mc_Entity.x == block.leaves2 ||
     mc_Entity.x == block.vine);

    blockEmissive = (mc_Entity.x == block.torch ||
     mc_Entity.x == block.glowstone ||
     mc_Entity.x == block.lava ||
     mc_Entity.x == block.lavaFlow ||
     mc_Entity.x == block.seaLantern ||
     mc_Entity.x == block.fire);

    blockWindFire = (mc_Entity.x == block.fire);

    blockMetallic = (mc_Entity.x == block.gold ||
     mc_Entity.x == block.iron ||
     mc_Entity.x == block.redstone ||
     mc_Entity.x == block.anvil ||
     mc_Entity.x == block.genericMetal);

    blockSubsurface = (mc_Entity.x == block.emerald ||
     mc_Entity.x == block.diamond);
}

void matSetup() {
    if (mc_Entity.x == block.tallgrass ||
     mc_Entity.x == block.doublegrass ||
     mc_Entity.x == block.shrub ||
     mc_Entity.x == block.wheat||
     mc_Entity.x == block.carrot||
     mc_Entity.x == block.potato ||
     mc_Entity.x == block.beets ||
     mc_Entity.x == 240 ||
     mc_Entity.x == 241 ||
     mc_Entity.x == block.genericGrass) {
        foliage = 1.0;
    } else if (mc_Entity.x == block.reed ||
     mc_Entity.x == block.vine ||
     mc_Entity.x == block.dandelion ||
     mc_Entity.x == block.poppy ||
     mc_Entity.x == block.genericCrop) {
         foliage = 0.5;
    } else if (mc_Entity.x == block.leaves ||
     mc_Entity.x == block.leaves2) {
        foliage = 0.3;
    } else {
        foliage = 0.0;
    }

    if (blockMetallic) {
        metal = 1;
    } else {
        metal = 0;
    }

    if (mc_Entity.x == block.torch ||
     mc_Entity.x == block.glowstone ||
     mc_Entity.x == block.seaLantern) {
        emissive = 0.5;
    } else if (blockEmissive) {
        emissive = 1.0;
    } else {
        emissive = 0.0;
    }

    if (blockSubsurface) {
        subsurface = 1;
        gem = 1;
    } else {
        subsurface = 0;
        gem = 0;
    }

    if (mc_Entity.x == block.lava ||
     mc_Entity.x == block.lavaFlow) {
        lava = 1;
    } else {
        lava = 0;
    }

    if (mc_Entity.x == block.snow) {
        snow = 1;
    } else {
        snow = 0;
    }
}