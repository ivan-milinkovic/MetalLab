#include <metal_stdlib>
using namespace metal;


struct VertexInput {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float4 color    [[attribute(2)]];
    float2 uv       [[attribute(3)]];
    float3 tan      [[attribute(4)]];
    float3 btan     [[attribute(5)]];
};

struct FragmentData {
    float4 positionClip [[position]];
    float4 positionWorld;
    float3 normal;
    float4 color;
    float2 uv;
    float3 tan;
    float3 btan;
    float textureAmount;
    float textureTiling;
    float normalMapTiling;
    float envMapReflectedAmount;
    float envMapRefractedAmount;
    float specularExponent;
};

struct SpotLight {
    float3 position;
    float3 direction;
    float3 color;
};

struct ObjectConstants {
    float4x4 modelMatrix;
    float textureAmount; // factor how much texture color to take
    float textureTiling;
    float normalMapTiling;
    float envMapReflectedAmount;
    float envMapRefractedAmount;
    float specularExponent;
};

struct FrameConstants {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix; // not used here, but maintains correct memory structure
    
    float3 directionalLightDir;
    float4x4 lightProjectionMatrix;
    
    SpotLight spotLight;
};



vertex FragmentData vertex_main(
    VertexInput vertexData [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    uint instanceId [[instance_id]],
    constant FrameConstants& frameConstants [[buffer(2)]]
) {
    auto objectConstants = objectConstantsArray[instanceId];
    FragmentData out;
    auto modelViewMatrix = frameConstants.viewMatrix * objectConstants.modelMatrix;
    out.positionClip = frameConstants.projectionMatrix * modelViewMatrix * float4(vertexData.position, 1);
    out.positionWorld = objectConstants.modelMatrix * float4(vertexData.position, 1);
    out.normal = normalize((modelViewMatrix * float4(vertexData.normal, 0)).xyz); // todo: model-view inverse transform
    out.tan    = normalize((modelViewMatrix * float4(vertexData.tan,    0)).xyz); // todo: model-view inverse transform
    out.btan   = normalize((modelViewMatrix * float4(vertexData.btan,   0)).xyz); // todo: model-view inverse transform
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    out.textureAmount = objectConstants.textureAmount;
    out.textureTiling = objectConstants.textureTiling;
    out.normalMapTiling = objectConstants.normalMapTiling;
    out.envMapReflectedAmount = objectConstants.envMapReflectedAmount;
    out.envMapRefractedAmount = objectConstants.envMapRefractedAmount;
    out.specularExponent = objectConstants.specularExponent;
    return out;
}


fragment float4 fragment_main
(
             FragmentData      fragmentData    [[stage_in]],
    constant FrameConstants&   frameConstants  [[buffer(0)]],
    texture2d   <float, access::sample> texture   [[texture(0)]],
    depth2d     <float, access::sample> shadowMap [[texture(1)]],
    texturecube <float, access::sample> cubeMap   [[texture(2)]],
    texture2d   <float, access::sample> normalMap [[texture(3)]],
    sampler                          sampler   [[sampler(0)]])
{
    //return {0, 0.2, 0.6, 1};
    //return shadowMap.sample(sampler, fragmentData.uv);
    //return normalMap.sample(sampler, fragmentData.uv * fragmentData.normalMapTiling);
    
    float2 uv = fragmentData.uv * fragmentData.textureTiling;
    
    float4 color = fragmentData.color;
    if (fragmentData.textureAmount > 0.0) {
        auto tcolor = texture.sample(sampler, uv);
        color = fragmentData.textureAmount * tcolor + (1 - fragmentData.textureAmount) * color;
    }
    
    float3 N = fragmentData.normal;
    if (!is_null_texture(normalMap))
    {
        auto normalSampler = sampler;
        //constexpr struct sampler trilinearSampler(coord::normalized, filter::linear, mip_filter::linear, address::repeat);
        //normalSampler = trilinearSampler;
        float3 mappedNormal = normalMap.sample(normalSampler, uv * fragmentData.normalMapTiling).xyz; // tangent space
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
    //float3 R = reflect(-pointToCameraDir, N); // specular based on mirror reflection ray
    //fSpec = saturate(dot(N, R));
    //if (fSpec < 0.9) { fSpec = 0.0; }
    
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



vertex float4 vertex_shadow(
    VertexInput vertexInput [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    const device FrameConstants&  frameConstants [[buffer(2)]],
    uint instanceId [[instance_id]])
{
    ObjectConstants staticData = objectConstantsArray[instanceId];
    return frameConstants.lightProjectionMatrix * staticData.modelMatrix * float4(vertexInput.position, 1);
}


struct ShowShadowFragmentData {
    float4 pos [[position]];
    float2 uv;
};

vertex ShowShadowFragmentData vertex_depth_show(
    const device float2* vertices [[buffer(0)]],
    const device float2* uvs      [[buffer(1)]],
    unsigned int i [[ vertex_id ]])
{
    ShowShadowFragmentData out;
    out.pos = float4(vertices[i], 0, 1);
    out.uv = uvs[i];
    return out;
}

fragment float4 fragment_depth_show
(
 ShowShadowFragmentData fragmentData [[stage_in]],
 texture2d<float, access::sample> texture [[texture(0)]],
 sampler sampler [[sampler(0)]])
{
    return texture.sample(sampler, fragmentData.uv);
}


float4 checker_board(float2 uv, float scale)
{
    int x = floor(uv.x / scale);
    int y = floor(uv.y / scale);
    bool isEven = (x + y) % 2;
    return isEven ? float4(1.0) : float4(0.0);
}

// vertex float4 basic_vertex( const device packed_float3* vertices [[ buffer(0) ]], unsigned int i [[ vertex_id ]]) { ... }
