#include <metal_stdlib>
using namespace metal;

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
