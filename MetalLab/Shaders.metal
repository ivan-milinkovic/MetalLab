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
};

struct Constants {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
};


vertex VertexOutput basic_vertex(
    VertexInput vertexData [[stage_in]],
    constant Constants& constants [[buffer(1)]])
{
    VertexOutput out;
    out.position = constants.projectionMatrix * constants.viewMatrix * float4(vertexData.position, 1);
    out.normal = vertexData.normal;
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    return out;
}


fragment half4 basic_fragment(VertexOutput fragmentData [[stage_in]]) {
    return half4(fragmentData.color);
}


/*
vertex float4 basic_vertex( const device packed_float3* vertices [[ buffer(0) ]], unsigned int i [[ vertex_id ]]) { ... }
 */
