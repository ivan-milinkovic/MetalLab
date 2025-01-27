
#ifndef matrix_inverse_h
#define matrix_inverse_h

// Orthonormal square matrices have identical transpose and inverse
// Other transforms (skew) need a general purpose inverse
// https://mathworld.wolfram.com/MatrixInverse.html
float3x3 mat_inverse(float3x3 m) {
    float m11 = m.columns[0].x;
    float m21 = m.columns[0].y;
    float m31 = m.columns[0].z;
    
    float m12 = m.columns[1].x;
    float m22 = m.columns[1].y;
    float m32 = m.columns[1].z;
    
    float m13 = m.columns[2].x;
    float m23 = m.columns[2].y;
    float m33 = m.columns[2].z;
    
    float det = m11 * m22 * m33  +  m12 * m23 * m31  +  m13 * m21 * m32
              - m11 * m23 * m32  -  m12 * m21 * m33  -  m13 * m22 * m31;
    
    // cofactors
    float c11 = m22*m33 - m23*m32;
    float c12 = m13*m32 - m12*m33;
    float c13 = m12*m23 - m13*m22;
    
    float c21 = m23*m31 - m21*m33;
    float c22 = m11*m33 - m13*m31;
    float c23 = m13*m21 - m11*m23;
    
    float c31 = m21*m32 - m22*m31;
    float c32 = m12*m31 - m11*m32;
    float c33 = m11*m22 - m12*m21;
    
    float3x3 C = float3x3(float3(c11, c21, c31), float3(c12, c22, c32), float3(c13, c23, c33));
    
    float3x3 inv = (1/det) * C;
    return inv;
}

#endif /* matrix_inverse_h */
