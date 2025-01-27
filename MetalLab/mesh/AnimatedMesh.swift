import Foundation
import Metal
import ModelIO
import MetalKit

class AnimatedMesh {
    var transform: Transform = .init()
    let material: Material
    
    let mtkVertexBuffer: MTKMeshBuffer
    let geometryType: MTLPrimitiveType
    
    let mtkIndexBuffer: MTKMeshBuffer
    let indexType: MTLIndexType
    let indexCount: Int
    
    let skeleton: MDLSkeleton
    let animation: MDLPackedJointAnimation
    
    var jointBindMats: [float4x4]
    var jointModelToLocalMats: [float4x4]
    var jointRestMats: [float4x4]
    
    var rootMat: float4x4 // scene coordinate space correction matrix
    
    var jointAnimMats: [float4x4]
    let animDuration: TimeInterval
    
    var objectConstantsBuff: MTLBuffer
    
    @MainActor
    init(_ device: MTLDevice) {
        let allocator = MTKMeshBufferAllocator(device: device)
        let url = Bundle.main.url(forResource: "coord1", withExtension: "usda")!
        let asset = MDLAsset(url: url, vertexDescriptor: VertexData.makeModelioVertexDescriptor(), bufferAllocator: allocator)
        
        let root = asset.childObjects(of: MDLObject.self).first(where: { $0.name == "root" })!
        rootMat = root.transform?.matrix ?? matrix_identity_float4x4 // orientation correction in the file
        
        let meshes = asset.childObjects(of: MDLMesh.self) as! [MDLMesh]
        
        let mesh = meshes.first!
        mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                             normalAttributeNamed: MDLVertexAttributeNormal,
                             tangentAttributeNamed: MDLVertexAttributeTangent)
        mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                             tangentAttributeNamed: MDLVertexAttributeTangent,
                             bitangentAttributeNamed: MDLVertexAttributeBitangent)
        let submesh = (mesh.submeshes!.firstObject! as! MDLSubmesh)
        
        //let animObj = asset.childObjects(of: MDLObject.self)
        //    .first(where: {
        //        $0.components.contains(where: { $0 is MDLAnimationBindComponent}) }
        //    )!
        //let animationBinding = animObj.components.first { $0 is MDLAnimationBindComponent } as! MDLAnimationBindComponent
        
        skeleton = asset.childObjects(of: MDLSkeleton.self).first! as! MDLSkeleton
        let animationBinding = skeleton.components.first { $0 is MDLAnimationBindComponent } as! MDLAnimationBindComponent
        animation = animationBinding.jointAnimation as! MDLPackedJointAnimation
        mtkVertexBuffer = mesh.vertexBuffers.first! as! MTKMeshBuffer
        mtkIndexBuffer = submesh.indexBuffer as! MTKMeshBuffer
        geometryType = mtlPrimitiveType(fromMdl: submesh.geometryType)!
        indexType = mtlIndexType(fromMdl: submesh.indexType)!
        indexCount = submesh.indexCount
        animDuration = asset.endTime - asset.startTime
        
        jointBindMats = .init(repeating: matrix_identity_float4x4, count: 4)
        jointRestMats = .init(repeating: matrix_identity_float4x4, count: 4)
        
        jointBindMats = skeleton.jointBindTransforms.float4x4Array
        jointRestMats = skeleton.jointRestTransforms.float4x4Array
        jointModelToLocalMats = jointBindMats.map { $0.inverse }
        jointAnimMats = .init(repeating: matrix_identity_float4x4, count: 4)
        
        var prototype = ObjectConstants()
        objectConstantsBuff = device.makeBuffer(bytes: &prototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        
        material = Material(color: [0.7, 0.3, 0.0])
        
        updateJointAnimMats(localAnimMats: jointRestMats)
    }
    
    func updateConstantsBuffer() {
        let objectConstants = objectConstantsBuff.contents().bindMemory(to: ObjectConstants.self, capacity: 1)
        objectConstants.pointee.modelMatrix = transform.matrix * rootMat
    }
    
    var animStart: TimeInterval = 0.0
    
    func startAnimation() {
        animStart = Time.shared.current
    }
    
    func updateAnim() {
        let animTotalTime = Time.shared.current - animStart
        let loopedTime = fmod(animTotalTime, animDuration)
        let ts = animation.translations.float3Array(atTime: loopedTime)
        let rs = animation.rotations.floatQuaternionArray(atTime: loopedTime)
        let ss = animation.scales.float3Array(atTime: loopedTime)
        
        let animMats = zip(ts, zip(rs, ss)).map {
            let (t, (r, s)) = $0
            return float4x4.make(t: t, r: r, s: s)
        }
        updateJointAnimMats(localAnimMats: animMats)
    }
    
    @inline(__always)
    func updateJointAnimMats(localAnimMats animMats: [float4x4]) {
        // from right to left: put vertex into joint local space, apply joint animation transform, apply parent transform
        jointAnimMats[0] =                    animMats[0] // * jointModelToLocalMats[0]
        jointAnimMats[1] = jointAnimMats[0] * animMats[1] * jointModelToLocalMats[1]
        jointAnimMats[2] = jointAnimMats[0] * animMats[2] * jointModelToLocalMats[2]
        jointAnimMats[3] = jointAnimMats[0] * animMats[3] * jointModelToLocalMats[3]
    }
}
