#include <metal_stdlib>
using namespace metal;


struct VertexInput {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color [[attribute(2)]];
    float2 uv [[attribute(3)]];
};

struct SpotLight {
    float3 position;
    float3 direction;
    float3 color;
};

struct FragmentData {
    float4 positionClip [[position]];
    float3 position;
    float3 normal;
    float4 color;
    float2 uv;
    float4 positionModel; // for shadow mapping
};

struct ObjectStaticData {
    float4x4 modelMatrix;
    float4x4 modelViewMatrix;
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewInverseTransposeMatrix;
    float4x4 modelLightProjectionMatrix;
    
    int2 isTextured; // boolean and int have size issues with swift
    
    float4 directionalLightDir;
    SpotLight spotLight;
    
    
};


vertex FragmentData vertex_main(
    VertexInput vertexData [[stage_in]],
    constant ObjectStaticData& staticData [[buffer(1)]])
{
    FragmentData out;
    out.positionClip = staticData.modelViewProjectionMatrix * float4(vertexData.position, 1);
    out.position = (staticData.modelViewMatrix * float4(vertexData.position, 1)).xyz;
    out.positionModel = float4(vertexData.position, 1);
    out.normal = normalize((staticData.modelViewInverseTransposeMatrix * float4(vertexData.normal, 0)).xyz);
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    return out;
}


float4 checker_board(float2 uv, float scale);


fragment float4 fragment_main(
    FragmentData fragmentData [[stage_in]],
    constant ObjectStaticData& staticData [[buffer(0)]],
    texture2d<float, access::sample> texture [[texture(0)]],
    depth2d<float, access::sample> shadowMap [[texture(1)]],
    sampler sampler [[sampler(0)]])
{
    //return shadowMap.sample(sampler, fragmentData.uv);
    
    float4 color = fragmentData.color;
    bool isTextured = staticData.isTextured.x == 1;
    if (isTextured) {
        color = texture.sample(sampler, fragmentData.uv);
    }
    
    // directional light
    float3 lightDir = staticData.directionalLightDir.xyz;
    lightDir = normalize(-lightDir);
    //float f = max(0.1, dot(fragmentData.normalView, lightDir)); // physically meaningfull
    float f_dirLight = abs(dot(fragmentData.normal, lightDir)); // light from both lightDir and -lightDir, looks better
    
    // point light
    float3 lightPos = staticData.spotLight.position;
    float3 toLight = normalize(lightPos - fragmentData.position.xyz);
    float f_light = max(0.0, dot(fragmentData.normal, toLight));
    float4 lightColor = float4(staticData.spotLight.color, 1);
    
    // read shadow map
    float4 shadowNDC = staticData.modelLightProjectionMatrix * fragmentData.positionModel;
    shadowNDC.xyz /= shadowNDC.w;
    shadowNDC.y *= -1;
    float2 shadowUV = shadowNDC.xy * 0.5 + 0.5;
    constexpr struct sampler shadowSampler(coord::normalized, address::clamp_to_edge, filter::linear, compare_func::greater_equal);
    float f_shadow = shadowMap.sample_compare(shadowSampler, shadowUV, shadowNDC.z - 5e-3f);
    f_shadow = 1 - f_shadow;
    //f_shadow = 1; // ignores shadow map
    
    float f_light2 = f_shadow * f_light + 0.2 * f_dirLight;
    float4 finalColor = f_light2 * (lightColor * color);
    finalColor.w = 1;
    return finalColor;
}



float4 checker_board(float2 uv, float scale)
{
    int x = floor(uv.x / scale);
    int y = floor(uv.y / scale);
    bool isEven = (x + y) % 2;
    return isEven ? float4(1.0) : float4(0.0);
}



vertex float4 vertex_shadow(
    VertexInput vertexInput [[stage_in]],
    constant ObjectStaticData& statics [[buffer(1)]])
{
    return statics.modelLightProjectionMatrix * float4(vertexInput.position, 1);
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

/*
vertex float4 basic_vertex( const device packed_float3* vertices [[ buffer(0) ]], unsigned int i [[ vertex_id ]]) { ... }
 */
