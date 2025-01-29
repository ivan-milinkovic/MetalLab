#ifndef Material_h
#define Material_h

struct Material {
    float4 color;
    float3 emissiveColor;
    float metalness;
    float roughness;
    float ambOcclusion;
    float opacity;
    
    float textureAmount; // factor how much texture color to take
    float textureTiling;
    float normalMapTiling;
    float envMapReflectedAmount;
    float envMapRefractedAmount;
    float specularExponent;
    float displacementFactor;
};

#endif /* Material_h */
