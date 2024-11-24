#include <metal_stdlib>
using namespace metal;

struct VertexInput {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color [[attribute(2)]];
    float2 uv [[attribute(3)]];
};

struct VertexOutput {
    float4 position [[position]];
    float3 normal;
    float4 color;
    float2 uv;
    bool is_textured;
    float3 lightDir;
};

struct ObjectStaticData {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewInverseTransposeMatrix;
    int2 is_textured; // boolean and int have size issues with swift
    float4 directionalLightDir;
};


vertex VertexOutput vertex_main(
    VertexInput vertexData [[stage_in]],
    constant ObjectStaticData& objectStaticData [[buffer(1)]])
{
    VertexOutput out;
    out.position = objectStaticData.modelViewProjectionMatrix * float4(vertexData.position, 1);
    out.normal = normalize((objectStaticData.modelViewInverseTransposeMatrix * float4(vertexData.normal, 0)).xyz);
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    out.is_textured = objectStaticData.is_textured.x == 1;
    out.lightDir = objectStaticData.directionalLightDir.xyz;
    return out;
}

float4 checker_board(float2 uv, float scale);

fragment float4 fragment_main(
    VertexOutput fragmentData [[stage_in]],
    texture2d<float, access::sample> texture [[texture(0)]],
    sampler sampler [[sampler(0)]])
{
    float3 lightDir = fragmentData.lightDir;
    lightDir = normalize(-lightDir);
    //float f = max(0.1, dot(fragmentData.normal, lightDir)); // physically meaningfull
    float f = abs(dot(fragmentData.normal, lightDir)); // light from both lightDir and -lightDir, looks better
    
    if (!fragmentData.is_textured) {
        return f*fragmentData.color;
    }
    return f*texture.sample(sampler, fragmentData.uv);
    
//    auto cb = checker_board(fragmentData.uv, 0.05);
//    return cb * fragmentData.color;
}

float4 checker_board(float2 uv, float scale)
{
    int x = floor(uv.x / scale);
    int y = floor(uv.y / scale);
    bool isEven = (x + y) % 2;
    return isEven ? float4(1.0) : float4(0.0);
}


/*
vertex float4 basic_vertex( const device packed_float3* vertices [[ buffer(0) ]], unsigned int i [[ vertex_id ]]) { ... }
 */
