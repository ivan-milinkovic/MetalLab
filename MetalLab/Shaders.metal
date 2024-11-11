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
};

struct Constants {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    int2 is_textured; // boolean and int have size issues with swift
};


vertex VertexOutput vertex_main(
    VertexInput vertexData [[stage_in]],
    constant Constants& constants [[buffer(1)]])
{
    VertexOutput out;
    out.position = constants.projectionMatrix * constants.viewMatrix * float4(vertexData.position, 1);
    out.normal = vertexData.normal;
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    out.is_textured = constants.is_textured.x == 1;
    return out;
}

float4 checker_board(float2 uv, float scale);

fragment float4 fragment_main(
    VertexOutput fragmentData [[stage_in]],
    texture2d<float, access::sample> texture [[texture(0)]],
    sampler sampler [[sampler(0)]])
{
    if (!fragmentData.is_textured) {
        return fragmentData.color;
    }
    return texture.sample(sampler, fragmentData.uv);
    
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
