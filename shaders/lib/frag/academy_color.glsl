/* this is a highly simplified version of the academy color encoding system rrt and odt */

/* sRGB_XYZ -> D65_D60 -> AP1 -> RRT */
const mat3 sRGB_AP1_RRT = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);
/* ODT -> XYZ -> D60_D65 -> XYZ_sRGB */
const mat3 ODT_sRGB = mat3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

struct academy_color_params {
    float slope;
    float toe;
    float shoulder;
    float black_clip;
    float white_clip;
};

vec3 academy_spline_fit(vec3 rgb_pre, const academy_color_params curve) {
    // approximated rrt spline based on unreal engine
    #if (defined MC_GL_RENDERER_INTEL || defined MC_GL_RENDERER_MESA || defined MC_GL_VENDOR_XORG)
        float toe_scale   = 1.0 + curve.black_clip - curve.toe;
        float shoulder_scale = 1.0 + curve.white_clip - curve.shoulder;
    #else
        const float toe_scale   = 1.0 + curve.black_clip - curve.toe;
        const float shoulder_scale = 1.0 + curve.white_clip - curve.shoulder;
    #endif

    const float in_match    = 0.18;
    const float out_match   = 0.18;

    float toe_match = 0.0;

    if (curve.toe > 0.8) {
        toe_match   = (1.0 - curve.toe - out_match) / curve.slope + log10(in_match);
    } else {
        #if (defined MC_GL_RENDERER_INTEL || defined MC_GL_RENDERER_MESA || defined MC_GL_VENDOR_XORG)
            float bt  = (out_match + curve.black_clip) / toe_scale - 1.0;
        #else
            const float bt  = (out_match + curve.black_clip) / toe_scale - 1.0;
        #endif
        
        toe_match   = log10(in_match) - 0.5 * log((1.0 + bt) * rcp(1.0 - bt)) * (toe_scale * rcp(curve.slope));
    }

    float straight_match    = (1.0 - curve.toe) / curve.slope - toe_match;
    float shoulder_match    = curve.shoulder / curve.slope - straight_match;

    vec3 log_color          = log10(rgb_pre);
    vec3 straight_color     = curve.slope * (log_color + straight_match);

    vec3 toe_color          = (-curve.black_clip) + (2.0 * toe_scale) * rcp(1.0 + exp((-2.0 * curve.slope / toe_scale) * (log_color - toe_match)));
    vec3 shoulder_color     = (1.0 + curve.white_clip) - (2.0 * shoulder_scale) * rcp(1.0 + exp((2.0 * curve.slope / shoulder_scale) * (log_color - shoulder_match)));

        toe_color           = smallerThanVec3(log_color, vec3(toe_match), toe_color, straight_color);
        shoulder_color      = greaterThanVec3(log_color, vec3(shoulder_match), shoulder_color, straight_color);

    vec3 t      = saturate((log_color - toe_match) * rcp(shoulder_match - toe_match));
        t       = shoulder_match < toe_match ? 1.0 - t : t;
        t       = (3.0 - 2.0 * t) * t * t;

    return mix(toe_color, shoulder_color, t);
}

vec3 academy_simplified(vec3 linear){
    const academy_color_params curve = academy_color_params(
        0.915,
        0.435,
        0.21,
        0.0,
        0.036
    );

	vec3 aces = linear*sRGB_AP1_RRT;

        aces  = academy_spline_fit(aces, curve);
        aces  = aces*ODT_sRGB;

    return to_srgb(aces);
}