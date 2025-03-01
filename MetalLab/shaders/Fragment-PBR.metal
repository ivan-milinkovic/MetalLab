#include <metal_stdlib>
using namespace metal;
#include "model/FragmentData.h"
#include "model/FrameConstants.h"
#include "model/ObjectConstants.h"
#include "model/Material.h"

// Reference:
// https://medium.com/@warrenm/thirty-days-of-metal-day-29-physically-based-rendering-e20e9c1bf984
// https://github.com/metal-by-example/thirty-days-of-metal/tree/master/29/MetalPBR

/// Map a value from one range to another
float remap(float value, float inMin, float inMax, float outMin, float outMax) {
    float inSize = inMax - inMin;
    float outSize = outMax - outMin;
    float f = (value - inMin) / inSize;
    return outMin + (f * outSize);
}

/// Normal distribution function, Trowbridge and Reitz (1975)
float calc_D(float alpha_sq, float cos_N_H) {
    auto denom = (alpha_sq - 1) * cos_N_H * cos_N_H + 1;
    denom *= denom;
    return alpha_sq * M_1_PI_F / denom;
}

/// Shadowing masking function, Smith (1967)
float calc_G1(float alpha_sq, float cos_N_X) {
    float tan_sq = (1 - cos_N_X) / max(cos_N_X, 0.001);
    return 2 / (1 + sqrt(1 + alpha_sq * tan_sq));
}

/// Total shadowing masking function
float calc_G(float alpha_sq, float cos_N_L, float cos_N_V) {
    return calc_G1(alpha_sq, cos_N_L) * calc_G1(alpha_sq, cos_N_V);
}

/// Fresnel reflection, Schlick (1994), F0 - specular reflectance
float3 calc_F(float3 F0, float VdotH) {
    float p = (1 - abs(VdotH));
    return F0 + (1 - F0) * (p*p*p*p*p);
}

fragment float4 fragment_main_pbr
(
                 FragmentData    fragmentData   [[stage_in]],
    constant     FrameConstants& frameConstants [[buffer(0)]],
    const device Material&       material       [[buffer(1)]],
 
    sampler                             sampler   [[sampler(0)]],
    texturecube <float, access::sample> cubeMap   [[texture(0)]],
    depth2d     <float, access::sample> shadowMap [[texture(1)]],
 
    texture2d   <float, access::sample> colorTex        [[texture(2)]],
    texture2d   <float, access::sample> normalTex       [[texture(3)]],
    texture2d   <float, access::sample> metalnessTex    [[texture(4)]],
    texture2d   <float, access::sample> roughnessTex    [[texture(5)]],
    texture2d   <float, access::sample> ambOcclusionTex [[texture(6)]],
    texture2d   <float, access::sample> emissiveTex     [[texture(7)]]
 )
{
    // Texture tiling
    float2 uv_diffuse = fragmentData.uv * material.textureTiling;
    float2 uv_normal = fragmentData.uv * material.normalMapTiling;
    
    // Base color
    float3 baseColor = !is_null_texture(colorTex) ? colorTex.sample(sampler, uv_diffuse).rgb : material.color.rgb;
    
    // Emissive
    float3 emissiveColor = !is_null_texture(emissiveTex) ? emissiveTex.sample(sampler, uv_diffuse).rgb : material.emissiveColor;
    
    // Read ambient, roughness and metallness as RGB in that order, that's how they are stored in textures (or single texture)
    
    // Ambient Occlusion
    float ambOcclusion = !is_null_texture(ambOcclusionTex) ? ambOcclusionTex.sample(sampler, uv_diffuse).r : material.ambOcclusion;
    
    // Roughness
    float roughness = !is_null_texture(roughnessTex) ? roughnessTex.sample(sampler, uv_diffuse).g : material.roughness;
    roughness = remap(roughness, 0.0, 1.0, 0.05, 1.0); // prevent division by zero
    
    // Metalness
    float metalness = !is_null_texture(metalnessTex) ? metalnessTex.sample(sampler, uv_diffuse).b : material.metalness;
    
    //return float4(float3(emissiveColor), 1);
    
    // Normal
    float3 N = fragmentData.normal;
    if (!is_null_texture(normalTex))
    {
        float3 mappedNormal = normalTex.sample(sampler, uv_normal).xyz; // tangent space
        mappedNormal = mappedNormal * 2 - 1;
        float3x3 TBN = { fragmentData.tan, fragmentData.btan, fragmentData.normal }; // columns, multiply with vectors on the right side, view space
        N = normalize( TBN * mappedNormal );
    }
    
    
    // Sample environment color
    float4 posView = frameConstants.viewMatrix * fragmentData.positionWorld; // position in view space
    float3 pointToCameraDir = normalize(-posView.xyz);
    float3 envReflectionColor = float3(0);
    {   // reflection based on a provided factor (not roughness), older implementation
        auto fRefl = material.envMapReflectedAmount;
        auto reflected = reflect(-pointToCameraDir, N);
        envReflectionColor = cubeMap.sample(sampler, reflected).rgb;
        baseColor = mix(baseColor, envReflectionColor, fRefl);
    }
    {   // refraction based on a provided factor
        auto fRefr = material.envMapRefractedAmount;
        auto refracted = refract(-pointToCameraDir, N, 1.33);
        auto refractionEnvColor = cubeMap.sample(sampler, refracted).rgb;
        baseColor = mix(baseColor, refractionEnvColor, fRefr);
    }
    
    
    // Shadow: sample shadow map texture
    float4 shadowNDC = frameConstants.lightProjectionMatrix * fragmentData.positionWorld;
    shadowNDC.xyz /= shadowNDC.w;
    shadowNDC.y *= -1;
    float2 shadowUV = shadowNDC.xy * 0.5 + 0.5;
    constexpr struct sampler shadowSampler(coord::normalized, address::clamp_to_edge, filter::linear, compare_func::greater_equal);
    float fShadow = shadowMap.sample_compare(shadowSampler, shadowUV, shadowNDC.z - 5e-3f);
    fShadow = 1 - fShadow;
    
    
    // Directional light, used as ambient light
    float3 lightDir = frameConstants.directionalLightDir;
    lightDir = normalize(-lightDir);
    //float fDirLight = max(0.1, dot(fragmentData.normal, lightDir)); // no backlight
    float fDirLight = abs(dot(N, lightDir)); // light from both lightDir and -lightDir, fakes ambient light, looks better
    float fAmbient = 0.2 * fDirLight;
    
    
    // BRDF
    auto pointToLightDir = normalize(frameConstants.spotLight.position - posView.xyz); // todo: multiple lights
    auto V = pointToCameraDir;
    auto L = pointToLightDir;
    auto H = normalize(V + L);
    
    // diffuse
    baseColor = mix(baseColor, envReflectionColor, roughness);
    float3 diffuseColor = mix(baseColor, float3(0.0), metalness);
    auto lambertian = diffuseColor * M_1_PI_F;
    auto fd = lambertian * ambOcclusion;
    
    // specular
    auto alpha = roughness * roughness;
    auto alpha_sq = alpha * alpha;
    auto NdotH = dot(N, H);
    auto NdotL = dot(N, L);
    auto NdotV = dot(N, V);
    auto VdotH = dot(V, H);
    auto F0 = mix(0.04, baseColor, metalness); // specular reflectance, 0.04 for dialectrics, metals tint reflections
    auto D = calc_D(alpha_sq, NdotH);
    auto G = calc_G(alpha_sq, NdotL, NdotV);
    auto F = calc_F(F0, VdotH);
    
    auto fs = (D * G * F) / (4.0f * abs(NdotL) * abs(NdotV));
    auto f = fd + fs;
    
    float3 lightIntensity = frameConstants.spotLight.intensity * frameConstants.spotLight.color;
    float3 color = (fShadow + fAmbient) * lightIntensity * saturate(NdotL) * f;
    color += emissiveColor;
    
    // Pre-multiply alpha
    float colorAlpha = material.opacity * material.color.a;
    color *= colorAlpha;
    
    // Manual gamma correction. Frame buffer pixel format `.rgba8Unorm_srgb` applies gamma automatically
    // color = sqrt(color);
    
    return float4(color, colorAlpha);
}
