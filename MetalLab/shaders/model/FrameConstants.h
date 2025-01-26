#ifndef FrameConstants_h
#define FrameConstants_h

#include "SpotLight.h"

struct FrameConstants {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 viewProjectionMatrix; // not used here, but maintains correct memory structure
    
    float3 directionalLightDir;
    float4x4 lightProjectionMatrix;
    
    SpotLight spotLight;
};

#endif /* FrameConstants_h */
