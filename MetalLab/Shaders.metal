#include <metal_stdlib>
using namespace metal;


struct VertexInput {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color [[attribute(2)]];
    float2 uv [[attribute(3)]];
};

struct FragmentData {
    float4 positionClip [[position]];
    float4 positionWorld;
    float3 normal;
    float4 color;
    float2 uv;
    bool isTextured;
};

struct SpotLight {
    float3 position;
    float3 direction;
    float3 color;
};

struct ObjectConstants {
    float4x4 modelMatrix;
    int2 isTextured; // boolean and int have size issues with swift
};

struct FrameConstants {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix;
    
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
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    out.isTextured = objectConstants.isTextured.x == 1;
    return out;
}


fragment float4 fragment_main(
             FragmentData      fragmentData    [[stage_in]],
    constant FrameConstants&   frameConstants  [[buffer(0)]],
    texture2d<float, access::sample> texture   [[texture(0)]],
    depth2d  <float, access::sample> shadowMap [[texture(1)]],
    sampler                          sampler   [[sampler(0)]])
{
    //return {0, 0.2, 0.6, 1};
    //return shadowMap.sample(sampler, fragmentData.uv);
    
    float4 color = fragmentData.color;
    if (fragmentData.isTextured) {
        color = texture.sample(sampler, fragmentData.uv);
    }
    
    // directional light
    float3 lightDir = frameConstants.directionalLightDir;
    lightDir = normalize(-lightDir);
    //float f_dirLight = max(0.1, dot(fragmentData.normal, lightDir)); // no backlight
    float fDirLight = abs(dot(fragmentData.normal, lightDir)); // light from both lightDir and -lightDir, looks better
    
    // point light
    float3 lightPos = frameConstants.spotLight.position;
    float3 toLight = normalize(lightPos - (frameConstants.viewMatrix * fragmentData.positionWorld).xyz);
    float fSpotLight = max(0.0, dot(fragmentData.normal, toLight));
    float4 lightColor = float4(frameConstants.spotLight.color, 1);
    
    // read shadow map
    float4 shadowNDC = frameConstants.lightProjectionMatrix * fragmentData.positionWorld;
    shadowNDC.xyz /= shadowNDC.w;
    shadowNDC.y *= -1;
    float2 shadowUV = shadowNDC.xy * 0.5 + 0.5;
    constexpr struct sampler shadowSampler(coord::normalized, address::clamp_to_edge, filter::linear, compare_func::greater_equal);
    float fShadow = shadowMap.sample_compare(shadowSampler, shadowUV, shadowNDC.z - 5e-3f);
    fShadow = 1 - fShadow;
    
    float f_light2 = fShadow * fSpotLight + 0.2 * fDirLight;
    float4 color2 = f_light2 * (lightColor * color);
    color2.w = color.w; // restore the original alpha channel after multiplications
    //finalColor.w = 1; // avoids transparency
    
    float4 color3 = float4(color2.xyz*color2.w, color2.w); // pre-multiply alpha
    
    // Gamma correction usage depends on pixel format of the frame-buffer, srgb will convert automatically from linear
    //return sqrt(color3); // manual gamma correction
    
    return color3;
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

struct UpdateShearConstants {
    float time_counter;
    uint count;
    float windStrength;
    float3 windDir;
};

struct UpdateShearStrandData {
    float3 position;
    float flexibility;
    float3 outShear;
};

kernel void update_shear (
 constant UpdateShearConstants&  constants     [[buffer(0)]],
 device   UpdateShearStrandData* stradDataBuff [[buffer(1)]],
 uint index [[thread_position_in_grid]])
{
    if (index >= constants.count) {
        stradDataBuff[index].outShear = float3(1,0,0);
        return;
    }
    
    auto t = stradDataBuff[index].position + constants.time_counter;
    t *= 0.75; // adjust wave length
    auto x = constants.windStrength * (sin(t.x) + sin(2*t.x) + sin(4*t.x)) + 0.25;
    auto y = constants.windStrength * (sin(t.y) + sin(2*t.y) + sin(4*t.y)) + 0.25;
    auto z = constants.windStrength * (sin(t.z) + sin(2*t.z) + sin(4*t.z)) + 0.25;
    x *= constants.windDir.x;
    y *= constants.windDir.y;
    z *= constants.windDir.z;
    stradDataBuff[index].outShear = float3(x, y, z);
}
