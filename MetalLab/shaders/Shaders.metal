#include <metal_stdlib>
using namespace metal;


struct VertexInput {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float4 color    [[attribute(2)]];
    float2 uv       [[attribute(3)]];
    float3 tan      [[attribute(4)]];
    float3 btan     [[attribute(5)]];
    ushort4 jointIndices [[attribute(6)]];
    float4 jointWeights  [[attribute(7)]];
};

struct FragmentData {
    float4 positionClip [[position]];
    float4 positionWorld;
    float3 normal;
    float4 color;
    float2 uv;
    float3 tan;
    float3 btan;
    float textureAmount;
    float textureTiling;
    float normalMapTiling;
    float envMapReflectedAmount;
    float envMapRefractedAmount;
    float specularExponent;
};

struct SpotLight {
    float3 position;
    float3 direction;
    float3 color;
};

struct ObjectConstants {
    float4x4 modelMatrix;
    float textureAmount; // factor how much texture color to take
    float textureTiling;
    float normalMapTiling;
    float envMapReflectedAmount;
    float envMapRefractedAmount;
    float specularExponent;
    float displacementFactor;
};

struct FrameConstants {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix; // not used here, but maintains correct memory structure
    
    float3 directionalLightDir;
    float4x4 lightProjectionMatrix;
    
    SpotLight spotLight;
};


FragmentData basic_vertex_transform(
  thread VertexInput& vertexData,
  thread const ObjectConstants& objectConstants,
  uint instanceId [[instance_id]],
  constant FrameConstants& frameConstants)
{
    FragmentData out;
    auto modelViewMatrix = frameConstants.viewMatrix * objectConstants.modelMatrix;
    out.positionClip = frameConstants.projectionMatrix * modelViewMatrix * float4(vertexData.position, 1);
    out.positionWorld = objectConstants.modelMatrix * float4(vertexData.position, 1);
    out.normal = normalize((modelViewMatrix * float4(vertexData.normal, 0)).xyz); // todo: model-view inverse transform
    out.tan    = normalize((modelViewMatrix * float4(vertexData.tan,    0)).xyz); // todo: model-view inverse transform
    out.btan   = normalize((modelViewMatrix * float4(vertexData.btan,   0)).xyz); // todo: model-view inverse transform
    out.color = vertexData.color;
    out.uv = vertexData.uv;
    out.textureAmount = objectConstants.textureAmount;
    out.textureTiling = objectConstants.textureTiling;
    out.normalMapTiling = objectConstants.normalMapTiling;
    out.envMapReflectedAmount = objectConstants.envMapReflectedAmount;
    out.envMapRefractedAmount = objectConstants.envMapRefractedAmount;
    out.specularExponent = objectConstants.specularExponent;
    return out;
}


vertex FragmentData vertex_main(
    VertexInput vertexData [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    uint instanceId [[instance_id]],
    constant FrameConstants& frameConstants [[buffer(2)]]
) {
    auto objectConstants = objectConstantsArray[instanceId];
    return basic_vertex_transform(vertexData, objectConstants, instanceId, frameConstants);
}

void applyAnimation
(
 thread VertexInput& vin,
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

vertex FragmentData vertex_main_anim(
    VertexInput vin [[stage_in]],
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
    VertexInput vin [[stage_in]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    const device FrameConstants&  frameConstants [[buffer(2)]],
    uint instanceId [[instance_id]],
    device const float4x4* jointModelMats [[buffer(3)]])
{
    applyAnimation(vin, jointModelMats);
    ObjectConstants objectConstants = objectConstantsArray[instanceId];
    return frameConstants.lightProjectionMatrix * objectConstants.modelMatrix * float4(vin.position, 1);
}


// interpolation referenced from here:
// https://github.com/metal-by-example/thirty-days-of-metal/blob/master/27/MetalTessellatedDisplacement/MetalTessellatedDisplacement/Shaders.metal

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

VertexInput tess_interpolate_triangle
(
 thread VertexInput& v0,
 thread VertexInput& v1,
 thread VertexInput& v2,
 float3 posInPatch,
 thread const ObjectConstants& objectConstants,
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
    
    auto d = displacementMap.sample(sampler, uv).r;
    pos += norm * d * objectConstants.displacementFactor;
    
    VertexInput vertexData = { pos, norm, col, uv, tan, btan};
    return vertexData;
}

[[patch(triangle, 3)]]
vertex FragmentData vertex_tesselation
(
 patch_control_point<VertexInput> controlPoints [[stage_in]],
 float3 posInPatch [[position_in_patch]],
 const device ObjectConstants* objectConstantsArray [[buffer(1)]],
 uint instanceId [[instance_id]],
 constant FrameConstants& frameConstants [[buffer(2)]],
 texture2d<float, access::sample> displacementMap [[texture(0)]],
 sampler sampler [[sampler(0)]]
 )
{
    auto v0 = controlPoints[0];
    auto v1 = controlPoints[1];
    auto v2 = controlPoints[2];
    auto objectConstants = objectConstantsArray[instanceId];
    
    VertexInput vertexData = tess_interpolate_triangle(v0, v1, v2, posInPatch, objectConstants, displacementMap, sampler);
    return basic_vertex_transform(vertexData, objectConstants, instanceId, frameConstants);
}

fragment float4 fragment_main
(
             FragmentData    fragmentData         [[stage_in]],
    constant FrameConstants& frameConstants       [[buffer(0)]],
    texture2d   <float, access::sample> texture   [[texture(0)]],
    depth2d     <float, access::sample> shadowMap [[texture(1)]],
    texturecube <float, access::sample> cubeMap   [[texture(2)]],
    texture2d   <float, access::sample> normalMap [[texture(3)]],
    sampler                             sampler   [[sampler(0)]])
{
    float2 uv = fragmentData.uv * fragmentData.textureTiling;
    
    float4 color = fragmentData.color;
    if (fragmentData.textureAmount > 0.0) {
        auto tcolor = texture.sample(sampler, uv);
        color = fragmentData.textureAmount * tcolor + (1 - fragmentData.textureAmount) * color;
    }
    
    float3 N = fragmentData.normal;
    if (!is_null_texture(normalMap))
    {
        float3 mappedNormal = normalMap.sample(sampler, uv * fragmentData.normalMapTiling).xyz; // tangent space
        mappedNormal = mappedNormal * 2 - 1;
        float3x3 TBN = { fragmentData.tan, fragmentData.btan, fragmentData.normal }; // columns, multiply with vectors on the right side, view space
        N = normalize( TBN * mappedNormal );
    }
    
    float4 posView = frameConstants.viewMatrix * fragmentData.positionWorld; // position in view space
    float3 pointToCameraDir = normalize(-posView.xyz);
    
    // environment mapping
    if (fragmentData.envMapReflectedAmount > 0.0) { // if because of transparent objects, see alpha component bellow
        // reflection
        auto fRefl = fragmentData.envMapReflectedAmount;
        auto reflected = reflect(-pointToCameraDir, N);
        auto reflectionEnvColor = cubeMap.sample(sampler, reflected).rgb;
        
        color = fRefl * float4(reflectionEnvColor, 1) + (1 - fRefl) * color;
    }
    if (fragmentData.envMapRefractedAmount > 0.0) {
        // refraction
        auto fRefr = fragmentData.envMapRefractedAmount;
        auto refracted = refract(-pointToCameraDir, N, 1.33);
        auto refractionEnvColor = cubeMap.sample(sampler, refracted).rgb;
        color = fRefr * float4(refractionEnvColor, 1) + (1 - fRefr) * color;
    }
    
    // directional light
    float3 lightDir = frameConstants.directionalLightDir;
    lightDir = normalize(-lightDir);
    //float fDirLight = max(0.1, dot(fragmentData.normal, lightDir)); // no backlight
    float fDirLight = abs(dot(N, lightDir)); // light from both lightDir and -lightDir, fakes ambient light, looks better
    
    // point light
    float3 lightPos = frameConstants.spotLight.position;
    float3 toLight = normalize(lightPos - posView.xyz);
    float fSpotLight = saturate(dot(N, toLight));
    float4 lightColor = float4(frameConstants.spotLight.color, 1);
    
    // read shadow map
    float4 shadowNDC = frameConstants.lightProjectionMatrix * fragmentData.positionWorld;
    shadowNDC.xyz /= shadowNDC.w;
    shadowNDC.y *= -1;
    float2 shadowUV = shadowNDC.xy * 0.5 + 0.5;
    constexpr struct sampler shadowSampler(coord::normalized, address::clamp_to_edge, filter::linear, compare_func::greater_equal);
    float fShadow = shadowMap.sample_compare(shadowSampler, shadowUV, shadowNDC.z - 5e-3f);
    fShadow = 1 - fShadow;
    
    // specular
    float3 H = normalize(toLight + pointToCameraDir); // half vector
    float fSpec = powr(saturate(dot(N, H)), fragmentData.specularExponent);
    
    // final color
    float f_light2 = fShadow * fSpotLight + 0.2 * fDirLight;
    float4 outColor = f_light2 * (lightColor * color);
    outColor += float4(fShadow * fSpec * frameConstants.spotLight.color, 0); // apply specular
    outColor.w = color.w; // restore the original alpha channel after multiplications
    //finalColor.w = 1; // avoids transparency
    
    outColor.xyz *= outColor.w; // pre-multiply alpha?
    
    // Gamma correction usage depends on pixel format of the frame-buffer, srgb will convert automatically from linear
    //outColor = sqrt(outColor); // manual gamma correction
    //outColor.w = color.w; // restore the original alpha channel again after gamma correction
    
    return outColor;
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

[[patch(triangle, 3)]]
vertex float4 vertex_shadow_tess
(
    patch_control_point<VertexInput> controlPoints [[stage_in]],
    float3 posInPatch [[position_in_patch]],
    uint instanceId [[instance_id]],
    const device ObjectConstants* objectConstantsArray [[buffer(1)]],
    const device FrameConstants&  frameConstants [[buffer(2)]],
    texture2d<float, access::sample> displacementMap [[texture(0)]],
    sampler sampler [[sampler(0)]])
{
    auto v0 = controlPoints[0];
    auto v1 = controlPoints[1];
    auto v2 = controlPoints[2];
    ObjectConstants objectConstants = objectConstantsArray[instanceId];
    VertexInput vertexData = tess_interpolate_triangle(v0, v1, v2, posInPatch, objectConstants, displacementMap, sampler);
    return frameConstants.lightProjectionMatrix * objectConstants.modelMatrix * float4(vertexData.position, 1);
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
