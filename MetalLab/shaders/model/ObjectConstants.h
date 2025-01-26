#ifndef ObjectConstants_h
#define ObjectConstants_h

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

#endif /* ObjectConstants_h */
