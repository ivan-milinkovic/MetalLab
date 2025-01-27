#include <metal_stdlib>
using namespace metal;
#include "model/VertexData.h"
#include "model/ObjectConstants.h"
#include "model/FrameConstants.h"
#include "model/FragmentData.h"
#include "model/Material.h"
#include "matrix-util.h"

FragmentData basic_vertex_transform(
  thread VertexData& vertexData,
  thread const ObjectConstants& objectConstants,
  uint instanceId [[instance_id]],
  constant FrameConstants& frameConstants)
{
    FragmentData out;
    auto modelViewMatrix = frameConstants.viewMatrix * objectConstants.modelMatrix;
    float3x3 upperLeft = float3x3(modelViewMatrix.columns[0].xyz, modelViewMatrix.columns[1].xyz, modelViewMatrix.columns[2].xyz);
    auto normalViewMatrix = transpose(mat_inverse(upperLeft));
    out.positionClip = frameConstants.projectionMatrix * modelViewMatrix * float4(vertexData.position, 1);
    out.positionWorld = objectConstants.modelMatrix * float4(vertexData.position, 1);
    out.normal = normalize(normalViewMatrix * vertexData.normal);
    out.tan    = normalize(normalViewMatrix * vertexData.tan);
    out.btan   = normalize(normalViewMatrix * vertexData.btan);
    out.uv = vertexData.uv;
    return out;
}


void applyAnimation
(
 thread VertexData& vin,
 device const float4x4* jointModelMats
 )
{
    auto animMat = vin.jointWeights[0] * jointModelMats[vin.jointIndices[0]]
                 + vin.jointWeights[1] * jointModelMats[vin.jointIndices[1]]
                 + vin.jointWeights[2] * jointModelMats[vin.jointIndices[2]]
                 + vin.jointWeights[3] * jointModelMats[vin.jointIndices[3]];
    auto pos = float4(vin.position, 1);
    auto normal = float4(vin.normal, 0);
    vin.position = (animMat * pos).xyz;
    vin.normal = (animMat * normal).xyz;
}


// Reference: https://github.com/metal-by-example/thirty-days-of-metal/blob/master/27/MetalTessellatedDisplacement/MetalTessellatedDisplacement/Shaders.metal
template<typename T>
T bilerp(T c00, T c01, T c10, T c11, float2 uv) // upper-left, upper-right, lower-left, lower-right, uv - normalized position within the patch
{
    T f1 = mix(c00, c01, T(uv[0])); // upper edge (x axis)
    T f2 = mix(c10, c11, T(uv[0])); // bottom edge (x axis)
    T f = mix(f1, f2, T(uv[1]));    // upper vs bottom factor (y axis)
    return f;
}

template <typename T>
T barycentric_interpolate(T c0, T c1, T c2, float3 bary_coords) {
    return c0 * bary_coords[0] + c1 * bary_coords[1] + c2 * bary_coords[2];
}


VertexData tess_interpolate_triangle
(
 thread VertexData& v0,
 thread VertexData& v1,
 thread VertexData& v2,
 float3 posInPatch,
 float textureTiling,
 float displacementFactor,
 thread const texture2d<float, access::sample>& displacementMap,
 thread const sampler& sampler
 )
{
    float3 pos  = barycentric_interpolate(v0.position, v1.position, v2.position, posInPatch);
    float3 norm = barycentric_interpolate(v0.normal,   v1.normal,   v2.normal,   posInPatch);
    float3 tan  = barycentric_interpolate(v0.tan,      v1.tan,      v2.tan,      posInPatch);
    float3 btan = barycentric_interpolate(v0.btan,     v1.btan,     v2.btan,     posInPatch);
    float4 col  = barycentric_interpolate(v0.color,    v1.color,    v2.color,    posInPatch);
    float2 uv   = barycentric_interpolate(v0.uv,       v1.uv,       v2.uv,       posInPatch);
    
    auto tiling = textureTiling;
    auto d = displacementMap.sample(sampler, uv*tiling).r;
    pos += norm * d * displacementFactor;
    
    VertexData vertexData = { pos, norm, col, uv, tan, btan};
    return vertexData;
}


vertex FragmentData vertex_main(
    VertexData vertexData [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    uint instanceId [[instance_id]],
    constant FrameConstants& frameConstants [[buffer(2)]]
) {
    auto objectConstants = objectConstantsArray[instanceId];
    return basic_vertex_transform(vertexData, objectConstants, instanceId, frameConstants);
}


vertex FragmentData vertex_main_anim(
    VertexData vin [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    uint instanceId [[instance_id]],
    constant FrameConstants& frameConstants [[buffer(2)]],
    device const float4x4* jointModelMats [[buffer(3)]]
) {
    applyAnimation(vin, jointModelMats);
    auto objectConstants = objectConstantsArray[instanceId];
    return basic_vertex_transform(vin, objectConstants, instanceId, frameConstants);
}


vertex float4 vertex_shadow_anim(
    VertexData vin [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    const device FrameConstants&  frameConstants [[buffer(2)]],
    uint instanceId [[instance_id]],
    device const float4x4* jointModelMats [[buffer(3)]])
{
    applyAnimation(vin, jointModelMats);
    ObjectConstants objectConstants = objectConstantsArray[instanceId];
    return frameConstants.lightProjectionMatrix * objectConstants.modelMatrix * float4(vin.position, 1);
}


[[patch(triangle, 3)]]
vertex FragmentData vertex_tesselation
(
 patch_control_point<VertexData> controlPoints [[stage_in]],
 float3 posInPatch [[position_in_patch]],
 const device ObjectConstants* objectConstantsArray [[buffer(1)]],
 uint instanceId [[instance_id]],
 constant FrameConstants& frameConstants [[buffer(2)]],
 const device Material& material [[buffer(3)]],
 texture2d<float, access::sample> displacementMap [[texture(0)]],
 sampler sampler [[sampler(0)]]
 )
{
    auto v0 = controlPoints[0];
    auto v1 = controlPoints[1];
    auto v2 = controlPoints[2];
    auto objectConstants = objectConstantsArray[instanceId];
    
    VertexData vertexData = tess_interpolate_triangle(v0, v1, v2, posInPatch, material.textureTiling, material.displacementFactor, displacementMap, sampler);
    return basic_vertex_transform(vertexData, objectConstants, instanceId, frameConstants);
}


vertex float4 vertex_shadow(
    VertexData vertexInput [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    const device FrameConstants&  frameConstants [[buffer(2)]],
    uint instanceId [[instance_id]])
{
    ObjectConstants staticData = objectConstantsArray[instanceId];
    return frameConstants.lightProjectionMatrix * staticData.modelMatrix * float4(vertexInput.position, 1);
}


[[patch(triangle, 3)]]
vertex float4 vertex_shadow_tess
(
    patch_control_point<VertexData> controlPoints [[stage_in]],
    float3 posInPatch [[position_in_patch]],
    uint instanceId [[instance_id]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    const device FrameConstants&  frameConstants [[buffer(2)]],
    const device Material& material [[buffer(3)]],
    texture2d<float, access::sample> displacementMap [[texture(0)]],
    sampler sampler [[sampler(0)]])
{
    auto v0 = controlPoints[0];
    auto v1 = controlPoints[1];
    auto v2 = controlPoints[2];
    ObjectConstants objectConstants = objectConstantsArray[instanceId];
    VertexData vertexData = tess_interpolate_triangle(v0, v1, v2, posInPatch, material.textureTiling, material.displacementFactor, displacementMap, sampler);
    return frameConstants.lightProjectionMatrix * objectConstants.modelMatrix * float4(vertexData.position, 1);
}
