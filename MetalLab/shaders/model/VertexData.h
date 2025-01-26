#ifndef VertexData_h
#define VertexData_h

struct VertexData {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float4 color    [[attribute(2)]];
    float2 uv       [[attribute(3)]];
    float3 tan      [[attribute(4)]];
    float3 btan     [[attribute(5)]];
    ushort4 jointIndices [[attribute(6)]];
    float4 jointWeights  [[attribute(7)]];
};

#endif /* VertexData_h */
