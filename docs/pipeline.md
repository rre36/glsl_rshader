<h3>Where's what:</h3>

deferred0   = pre-linearize scene color

deferred1   = lighting preprocessing

deferred2   = lighting application

deferred3+  = sky calculation and application


composite0  = volumetrics, fog

composite1+  = post-processing effects (lens flares, motionblur, taa, dof, bloom)


final       = tonemapping and scene output


<h3>buffer usage:</h3>

fragData0   = scene color

fragData1   = scene normals

fragData2   = lightmap(torchlight, skylight), encoded pbr(roughness, specular, metalness)

fragData3   = gbuffer masks, material masks. empty.ba

fragData4   = empty.rgb (later storing gi), ambient occlusion

fragData6   = translucents

fragData7   = temporals


<h3>specific for kappa shader update:</h3>

initial setup:

frag0       = scene color
frag1       = scene normals
frag2       = lightmap.xy, encodedPbr(specular, roughness)
frag3       = gbuffer masks, material masks, metalness
frag4       = empty.rgb (gi in shading pass), ambient occlusion


deferred shading pass:

frag2       = lightmap.xy, encodedPbr(specular, roughness), encoded shadowcolor
frag4       = indirect lighting (gi), ao
frag5       = direct lighting, specular, empty.ba


gbuffers_water:

frag6       = translucents


cloud passes (deferred4-5 for layered, composite0+1 for volumetric)

frag4       = volumetric clouds


composite2 fog pass, blending translucents

frag4       = volumetric fog


composite3, 4 reflection passes

frag4       = pre-blurred volumetric fog
frag5       = planar reflection data
frag6       = temporary data


composite5 taa pass

frag7       = temporals


composite6 bloom, motionblur and lens pre-pass

frag4       = bloom data
frag5       = pre-blurred lens color (bokeh based)


composite7 bloom apply and bokeh dof 

frag4       = calculated lens flares


composite8 blur and apply lens flare

frag0       = final scene color sent into tonemapper


    => necessary buffer types:
    frag0   = rgb16f
    frag1   = rgb16
    frag2   = rgba16
    frag3   = rgb8
    frag4   = rgba16f
    frag5   = rgb16f
    frag6   = rgba16
    frag7   = rgba16f