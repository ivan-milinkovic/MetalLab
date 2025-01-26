#ifndef FragmentData_h
#define FragmentData_h

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

#endif /* FragmentData_h */
