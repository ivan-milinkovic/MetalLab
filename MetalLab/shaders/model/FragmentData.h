#ifndef FragmentData_h
#define FragmentData_h

struct FragmentData {
    float4 positionClip [[position]];
    float4 positionWorld;
    float3 normal;
    float2 uv;
    float3 tan;
    float3 btan;
};

#endif /* FragmentData_h */
