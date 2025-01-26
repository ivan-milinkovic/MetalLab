#include <metal_stdlib>
using namespace metal;
#include "model/FragmentData.h"
#include "model/FrameConstants.h"

fragment float4 fragment_main
(
             FragmentData    fragmentData         [[stage_in]],
    constant FrameConstants& frameConstants       [[buffer(0)]],
    texture2d   <float, access::sample> texture   [[texture(0)]],
    depth2d     <float, access::sample> shadowMap [[texture(1)]],
    texturecube <float, access::sample> cubeMap   [[texture(2)]],
    texture2d   <float, access::sample> normalMap [[texture(3)]],
    sampler                             sampler   [[sampler(0)]])
{
    float2 uv_diffuse = fragmentData.uv * fragmentData.textureTiling;
    float2 uv_normal = fragmentData.uv * fragmentData.normalMapTiling;
    
    float4 color = fragmentData.color;
    if (fragmentData.textureAmount > 0.0) {
        auto tcolor = texture.sample(sampler, uv_diffuse);
        color = fragmentData.textureAmount * tcolor + (1 - fragmentData.textureAmount) * color;
    }
    
    float3 N = fragmentData.normal;
    if (!is_null_texture(normalMap))
    {
        float3 mappedNormal = normalMap.sample(sampler, uv_normal).xyz; // tangent space
        mappedNormal = mappedNormal * 2 - 1;
        float3x3 TBN = { fragmentData.tan, fragmentData.btan, fragmentData.normal }; // columns, multiply with vectors on the right side, view space
        N = normalize( TBN * mappedNormal );
    }
    
    float4 posView = frameConstants.viewMatrix * fragmentData.positionWorld; // position in view space
    float3 pointToCameraDir = normalize(-posView.xyz);
    
    // environment mapping
    if (fragmentData.envMapReflectedAmount > 0.0) { // if because of transparent objects, see alpha component bellow
        // reflection
        auto fRefl = fragmentData.envMapReflectedAmount;
        auto reflected = reflect(-pointToCameraDir, N);
        auto reflectionEnvColor = cubeMap.sample(sampler, reflected).rgb;
        
        color = fRefl * float4(reflectionEnvColor, 1) + (1 - fRefl) * color;
    }
    if (fragmentData.envMapRefractedAmount > 0.0) {
        // refraction
        auto fRefr = fragmentData.envMapRefractedAmount;
        auto refracted = refract(-pointToCameraDir, N, 1.33);
        auto refractionEnvColor = cubeMap.sample(sampler, refracted).rgb;
        color = fRefr * float4(refractionEnvColor, 1) + (1 - fRefr) * color;
    }
    
    // directional light
    float3 lightDir = frameConstants.directionalLightDir;
    lightDir = normalize(-lightDir);
    //float fDirLight = max(0.1, dot(fragmentData.normal, lightDir)); // no backlight
    float fDirLight = abs(dot(N, lightDir)); // light from both lightDir and -lightDir, fakes ambient light, looks better
    
    // point light
    float3 lightPos = frameConstants.spotLight.position;
    float3 toLight = normalize(lightPos - posView.xyz);
    float fSpotLight = saturate(dot(N, toLight));
    float4 lightColor = float4(frameConstants.spotLight.color, 1);
    
    // read shadow map
    float4 shadowNDC = frameConstants.lightProjectionMatrix * fragmentData.positionWorld;
    shadowNDC.xyz /= shadowNDC.w;
    shadowNDC.y *= -1;
    float2 shadowUV = shadowNDC.xy * 0.5 + 0.5;
    constexpr struct sampler shadowSampler(coord::normalized, address::clamp_to_edge, filter::linear, compare_func::greater_equal);
    float fShadow = shadowMap.sample_compare(shadowSampler, shadowUV, shadowNDC.z - 5e-3f);
    fShadow = 1 - fShadow;
    
    // specular
    float3 H = normalize(toLight + pointToCameraDir); // half vector
    float fSpec = powr(saturate(dot(N, H)), fragmentData.specularExponent);
    
    // final color
    float f_light2 = fShadow * fSpotLight + 0.2 * fDirLight;
    float4 outColor = f_light2 * (lightColor * color);
    outColor += float4(fShadow * fSpec * frameConstants.spotLight.color, 0); // apply specular
    outColor.w = color.w; // restore the original alpha channel after multiplications
    //finalColor.w = 1; // avoids transparency
    
    outColor.xyz *= outColor.w; // pre-multiply alpha?
    
    // Gamma correction usage depends on pixel format of the frame-buffer, srgb will convert automatically from linear
    //outColor = sqrt(outColor); // manual gamma correction
    //outColor.w = color.w; // restore the original alpha channel again after gamma correction
    
    return outColor;
}

