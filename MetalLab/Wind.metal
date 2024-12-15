#include <metal_stdlib>
using namespace metal;

float4x4 matrix_from_quaternion(float4 q) {
    float4x4 m = float4x4();
    
    float qx2 = q.x * q.x;
    float qy2 = q.y * q.y;
    float qz2 = q.z * q.z;
    
    m[0][0] = 1 - 2*qy2 - 2*qz2;
    m[0][1] = 2*q.x*q.y - 2*q.z*q.w;
    m[0][2] = 2*q.x*q.z + 2*q.y*q.w;
    
    m[1][0] = 2*q.x*q.y + 2*q.z*q.w;
    m[1][1] = 1 - 2*qx2 - 2*qz2;
    m[1][2] = 2*q.y*q.z - 2*q.x*q.w;
    
    m[2][0] = 2*q.x*q.z - 2*q.y*q.w;
    m[2][1] = 2*q.y*q.z + 2*q.x*q.w;
    m[2][2] = 1 - 2*qx2 - 2*qy2;
    
    m[3][3] = 1;
    
    return m;
}

float4x4 matrix_from_shear(float3 shear) {
    return float4x4(float4(1, shear.y, shear.z, 0),
                    float4(shear.x, 1, shear.z, 0),
                    float4(0, 0, 1, 0),
                    float4(0, 0, 0, 1));
}

struct UpdateShearConstants {
    float time_counter;
    uint count;
    float windStrength;
    float3 windDir;
    float4x4 containerMat; // positioning of object containing all the instances
};

struct UpdateShearStrandData {
    float4x4 matrix;
    float3 position;
    float scale;
    float4 orient_quat;
    float3 shear;
    float flexibility;
};

kernel void update_shear (
 constant UpdateShearConstants&  constants     [[buffer(0)]],
 device   UpdateShearStrandData* strandDataBuff [[buffer(1)]],
 uint index [[thread_position_in_grid]])
{
    if (index >= constants.count) {
        strandDataBuff[index].shear = float3(1,0,0);
        return;
    }
    
    UpdateShearStrandData data = strandDataBuff[index];
    float3 posWorld = (constants.containerMat * float4(data.position, 1)).xyz;
    auto t = posWorld + constants.time_counter;
    t *= 0.75; // adjust wave length
    auto x = constants.windStrength * (sin(t.x) + sin(2*t.x) + sin(4*t.x)) + 0.25;
    auto y = constants.windStrength * (sin(t.y) + sin(2*t.y) + sin(4*t.y)) + 0.25;
    auto z = constants.windStrength * (sin(t.z) + sin(2*t.z) + sin(4*t.z)) + 0.25;
    x *= constants.windDir.x;
    y *= constants.windDir.y;
    z *= constants.windDir.z;
    data.shear = float3(x, y, z) * data.flexibility;
    
    auto shearMat = matrix_from_shear(data.shear);
    
    float4x4 identity = float4x4(1.0);
    auto scaleMat = identity * data.scale;
    scaleMat.columns[3].w = 1; // restore w after scaling
    
    auto rotMat = matrix_from_quaternion(data.orient_quat);
    auto transMat = float4x4(float4(1,0,0,0), float4(0,1,0,0), float4(0,0,1,0),
                             float4(data.position, 1));
    
    data.matrix = constants.containerMat * transMat * rotMat * scaleMat * shearMat;
    
    strandDataBuff[index] = data;
}



