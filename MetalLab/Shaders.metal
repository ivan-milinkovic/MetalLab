#include <metal_stdlib>
using namespace metal;


struct VertexInput {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float4 color [[attribute(2)]];
    float2 uv [[attribute(3)]];
};

struct PointLight {
    float3 position;
    float3 color;
};

struct VertexOutput {
    float4 positionClip [[position]];
    float3 position;
    float3 normal;
    float4 color;
    float2 uv;
};

struct ObjectStaticData {
    float4x4 modelMatrix;
    float4x4 modelViewMatrix;
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewInverseTransposeMatrix;
    int2 isTextured; // boolean and int have size issues with swift
    float4 directionalLightDir;
    PointLight pointLight;
};



vertex VertexOutput vertex_main(
    VertexInput vertexData [[stage_in]],
    constant ObjectStaticData& staticData [[buffer(1)]])
{
    VertexOutput out;
    out.positionClip = staticData.modelViewProjectionMatrix * float4(vertexData.position, 1);
    out.position = (staticData.modelViewMatrix * float4(vertexData.position, 1)).xyz;
    out.normal = normalize((staticData.modelViewInverseTransposeMatrix * float4(vertexData.normal, 0)).xyz);
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    return out;
}


float4 checker_board(float2 uv, float scale);


fragment float4 fragment_main(
    VertexOutput fragmentData [[stage_in]],
    constant ObjectStaticData& staticData [[buffer(2)]],
    texture2d<float, access::sample> texture [[texture(0)]],
    sampler sampler [[sampler(0)]])
{
    //float3 lightDir = staticData.directionalLightDir.xyz;
    //lightDir = normalize(-lightDir);
    //float f = max(0.1, dot(fragmentData.normalView, lightDir)); // physically meaningfull
    //float f = abs(dot(fragmentData.normalView, lightDir)); // light from both lightDir and -lightDir, looks better
    
    float3 lightPos = staticData.pointLight.position;
    float3 toLight = normalize(lightPos - fragmentData.position.xyz);
    float f = max(0.1, dot(fragmentData.normal, toLight));
    
    if (f > 100000000) {
        return float4(1,0,0,1);
    }
    
    bool is_textured = staticData.isTextured.x == 1;
    if (!is_textured) {
        return f * float4(staticData.pointLight.color, 1) * fragmentData.color;
    }
    return f * float4(staticData.pointLight.color, 1) * texture.sample(sampler, fragmentData.uv);
    
    //auto cb = checker_board(fragmentData.uv, 0.05);
    //return cb * fragmentData.color;
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
