import Foundation
import simd

// https://gamedev.stackexchange.com/questions/68612/how-to-compute-tangent-and-bitangent-vectors/68617#68617
/*
 t - tangent float 3
 b - bitangent float 3
 e1 - p0 to p1
 e2 - p0 to p2
 
 | e1 | = | du1 dv1 | * | t |
 | e2 |   | du2 dv2 |   | b |

                     -1
 | e1 | * | du1 dv1 |  = | t |
 | e2 |   | du2 dv2 |    | b |
 
 
 | t | = _________1_________ | * |  dv2 -dv1 | * | e1 |
 | b |   du1 * dv2 - dv1*du2 |   | -du2  du1 |   | e2 |

 
 
 Inverse of the delta matrix above:
 
 starting matrix:
 S:
 | du1 dv1 |
 | du2 dv2 |
 
 minor:
 M = | dv2 du2 |
     | dv1 du1 |
 
 cofactor:
 C = |  dv2 -du2 |
     | -dv1  du1 |
 
        T
 Adj = C  = |  dv2 -dv1 |
            | -du2  du1 |
 
 Det = 1 / ( du1 * dv2 - dv1 * du2 )
 
  -1
 S  = 1/Det(S) * Adj(S)
 
 // https://www.cuemath.com/algebra/adjoint-of-a-matrix/
 
 */

/**
Calculate tangent and bitangent for a given triangle.
p0, p1, p2: triangle vertices.
uv0, uv1, uv2: uv coordinates for each triangle vertex.
n: triangle normal.
 */
func makeTangent(p0: Float3, p1: Float3, p2: Float3, uv0: Float2, uv1: Float2, uv2: Float2, n: Float3) -> (tan: Float3, btan: Float3) {
    let e1 = p1 - p0
    let e2 = p2 - p0
    let du1 = uv1.x - uv0.x
    let dv1 = uv1.y - uv0.y
    let du2 = uv2.x - uv0.x
    let dv2 = uv2.y - uv0.y
    let det = 1 / ( du1 * dv2 - dv1 * du2 )
    let D = simd_float2x2(rows: [ [dv2, -dv1], [-du2, du1] ])
    let E = simd_float3x2(rows: [e1, e2])
    
    let T = det * D * E
    
    let vs = T.transpose.columns // the api only gives columns, but we need rows
    var t = vs.0
    var b = vs.1
    
    t = normalize(t - n*dot(n,t))
    b = normalize(b - n*dot(n,b))
    
    return (t, b)
}
