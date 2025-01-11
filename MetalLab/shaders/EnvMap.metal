#include <metal_stdlib>
using namespace metal;

struct EnvMapVertexOut {
    float4 position [[position]]; // transformed to screen space, just here for the pipeline
    float4 clipPosition; // interpolated, and used later to inverse transform from clip -> view -> world
};

vertex EnvMapVertexOut env_map_vertex(uint index [[vertex_id]]) {
    // triangle that covers the whole screen
    float2 triangleVertices[3] = {
        { -1,  1 }, // top left
        { -1, -3 }, // bot left
        {  3,  1 }, // top right
    };
    EnvMapVertexOut out;
    // if depthCompareFunction = .lessEqual, then use z=1
    // if depthCompareFunction = .less, then use z=0.98
    float4 pos = float4(triangleVertices[index], 1, 1); // z:1, w:1 is max distance
    out.position = pos;
    out.clipPosition = pos;
    return out;
}

fragment float4 env_map_fragment
(
 EnvMapVertexOut data [[stage_in]],
 constant float4x4 &inverseViewProject [[buffer(0)]],
 texturecube<float, access::sample> cubeTex [[texture(0)]],
 sampler sampler [[sampler(0)]]
 )
{
//    return float4(0.4 , 0.4, 0.8, 1.0);
    
    auto posWorld = inverseViewProject * data.clipPosition;
    auto dir = normalize(posWorld.xyz);
    return cubeTex.sample(sampler, dir);
}

