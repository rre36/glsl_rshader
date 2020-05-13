/*
====================================================================================================

    Copyright (C) 2020 RRe36

    All Rights Reserved unless otherwise explicitly stated.


    By downloading this you have agreed to the license and terms of use.
    These can be found inside the included license-file
    or here: https://rre36.github.io/license/

    Violating these terms may be penalized with actions according to the Digital Millennium
    Copyright Act (DMCA), the Information Society Directive and/or similar laws
    depending on your country.

====================================================================================================
*/

    #define vcloud_enabled
    #define vcloud_samples 30   //[15 20 25 30 35 40 45 50]
    #define vcloud_alt 260.0    //[175.0 180.0 185.0 190.0 195.0 200.0 210.0 220.0 230.0 240.0 250.0]
    #define vcloud_depth 175.0  //[250.0 275.0 300.0 325.0 350.0 400.0]
    #define vcloud_clip 12000.0

/* ------ lighting settings ------ */
//#define shadowfilter_hq
#define minlight_luma 0.1   //[0.1 0.2 0.3 0.4 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.5 3.0 3.5 4.0 5.0 6.0 7.0 8.0 9.0 10.0]

    /* ------ effects settings ------ */
    #define ambientOcclusion_enabled


/* ------ world settings ------ */
#define wind_effects_enabled
#define wind_intensity 1.0  //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]


/* ------ post processing settings ------ */
#define taa_enabled
#define image_sharpen
#define bloom_enabled

    /* ------ exposure settings ------ */
    #define exposure_minlum 1.0     //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.4 1.6 1.8 2.0 2.2. 2.4 2.6 2.8 3.0 3.5 4.0 5.0 6.0 8.0 10.0 15.0 20.0]
    #define exposure_speed 1.0      //[0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0 2.5 3.0 4.0]
    //#define manual_exposure_enabled
    #define manual_exposure 5.0     //[0.1 0.3 0.5 1.0 1.5 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 12.0 14.0 16.0 18.0 20.0 25.0 30.0 40.0 50.0]


/* ------ internals ------ */
#define DEBUG_VIEW 0    //[0 1 2 3 4] 0-off, 1-whiteworld, 2-ao
#define SKY_RENDER_LOD 2
#define CLOUD_RENDER_LOD 5.0
#define SKYREF_LOD 3.0
#define cloud_atmos_density 18e-5