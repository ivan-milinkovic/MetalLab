import simd
import Metal
import CoreImage

class GrassController {
    
    let grass: AnimatedInstancedObject!
    let updateShearOnGpu = true
    let pipelineState: MTLComputePipelineState
    let commandQueue: MTLCommandQueue
    
    init(grass: AnimatedInstancedObject, pipelineState: MTLComputePipelineState, commandQueue: MTLCommandQueue) {
        self.grass = grass
        self.pipelineState = pipelineState
        self.commandQueue = commandQueue
    }
    
    static func makeGrass(_ device: MTLDevice, commandQueue: MTLCommandQueue) -> GrassController {
        
        let url = Bundle.main.url(forResource: "perlin", withExtension: "png")!
        let dp = CGDataProvider(url: url as CFURL)!
        let img = CGImage(pngDataProviderSource: dp, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let bytesPerPixel = img.bitsPerPixel / img.bitsPerComponent
        let bytesPerRow = img.bytesPerRow
        let perlinSize = img.width // expects rectangular image
        
        // Have to copy the bytes, otherwise there are issues getting wrong values when using CFDataGetBytePtr(img.dataProvider!.data!)!
        var perlinBytes = [UInt8].init(repeating: 0, count: bytesPerRow*perlinSize)
        let ctx: CGContext = CGContext(data: &perlinBytes,
                                       width: perlinSize,
                                       height: perlinSize,
                                       bitsPerComponent: img.bitsPerComponent,
                                       bytesPerRow: bytesPerRow,
                                       space: CGColorSpaceCreateDeviceGray(),
                                       bitmapInfo: img.bitmapInfo.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: perlinSize, height: perlinSize))
        
        var instancePositions: [Transform] = []
        
        let rectSize: Float = 4
        let objectScale: Float = 0.2
        var strandWidth: Float = 0.1
        strandWidth = strandWidth * objectScale * 2 // 0.04
        let offsetLimits = strandWidth * 0.5
        let perlinUvScale: Float = 2
        
        for iy in stride(from: 0, through: rectSize, by: strandWidth) {
            for ix in stride(from: 0, through: rectSize, by: strandWidth) {
                // position jitter
                let posOffset = Float.random(in: -offsetLimits...offsetLimits)
                
                let orientation = simd_quatf(angle: Float.random(in: 0.0...0.2) * .pi, axis: [0, 1, 0])
                
                // scale from noise and jitter
                // proportional mapping: how far are we through the grass area rectangle - same proportion index into perlin
                let perlinX_ = (ix / rectSize) * Float(perlinSize)
                let perlinY_ = (iy / rectSize) * Float(perlinSize)
                // scale and wrap around perlin texture coordinates
                let perlinX = Int(perlinX_ * perlinUvScale) % perlinSize
                let perlinY = Int(perlinY_ * perlinUvScale) % perlinSize
                let ind = perlinY * bytesPerRow + perlinX * bytesPerPixel
                let perlinScale = Float(perlinBytes[ind]) / 255.0
                let scale = (objectScale * Float.random(in: 0.8...1.2)) + (perlinScale * 0.16)
                //let scale = perlinScale * 0.3 // visualize perlin
                
                // make
                instancePositions.append(Transform(position: [ix + posOffset, 0.0, -iy + posOffset], orientation: orientation, scale: scale))
            }
        }
        let count = instancePositions.count
        
        var flexibility = [Float](repeating: 0, count: count)
        for i in 0..<count {
            flexibility[i] = Float.random(in: 0.3...1.0)
        }
        
        let mesh = MetalMesh.grassStrand(device)
        let grass = AnimatedInstancedObject(metalMesh: mesh, positions: instancePositions, flexibility: flexibility, device: device)
        
        grass.transform.moveBy([0, 0, 1])
        
        let lib = device.makeDefaultLibrary()!
        let pipelineState = try! device.makeComputePipelineState(function: lib.makeFunction(name: "update_shear")!)
        
        return GrassController(grass: grass, pipelineState: pipelineState, commandQueue: commandQueue)
    }
    
    func updateShear(timeCounter: Double, wind: Wind, characterPos: Float3?) {
        if updateShearOnGpu {
            updateShearGpu(timeCounter: timeCounter, wind: wind)
        } else {
            updateShearOnCpu(timeCounter: timeCounter, wind: wind)
        }
        if let characterPos {
            moveGrassAwayFromCharacter(characterPos)
        }
    }
    
    func updateShearOnCpu(timeCounter: Double, wind: Wind) {
        
        let modelMat = grass.transform.matrix
        let instanceDataPtr = grass.instanceDataBuff.contents().assumingMemoryBound(to: UpdateShearStrandData.self)
        var i=0; while i<grass.count { defer { i += 1 }
            // using buffer for compatibility with the GPU version, see AnimatedInstancedObject.updateConstantsBuffer, it reads from the buffer, not positions
            var data = instanceDataPtr.advanced(by: i).pointee
            
            // sample wind based on world position and update shear
            let pos = (modelMat * data.position.float4_w1).xyz
            let sample = wind.sample(position: pos, timeCounter: timeCounter)
            data.shear = sample * data.flexibility
            
            // calculate the model to world matrix
            let transform = Transform(position: data.position, orientation: simd_quatf(vector: data.orientQuat), scale: data.scale, shear: data.shear)
            data.matrix = modelMat * transform.matrix
            
            // data is a copy, store it back
            instanceDataPtr.advanced(by: i).pointee = data
        }
    }
    
    func updateShearGpu(timeCounter: Double, wind: Wind) {
        guard grass != nil else { return }
        
        let cmdBuff = commandQueue.makeCommandBuffer()!
        cmdBuff.pushDebugGroup("Update Shear")
        let enc = cmdBuff.makeComputeCommandEncoder()!
        
        enc.setComputePipelineState(pipelineState)
        
        let modelMat = grass.transform.matrix
        
        let shearConstants = grass.instanceConstantsBuff.contents().bindMemory(to: UpdateShearConstants.self, capacity: 1)
        shearConstants.pointee.timeCounter = Float(timeCounter)
        shearConstants.pointee.count = UInt32(grass.count)
        shearConstants.pointee.windStrength = wind.strength
        shearConstants.pointee.windDir = wind.dir
        shearConstants.pointee.containerMat = modelMat
        
        enc.setBuffer(grass.instanceConstantsBuff, offset: 0, index: 0)
        enc.setBuffer(grass.instanceDataBuff, offset: 0, index: 1)
        
        let tnum = 32
        let threadsPerThreadgroup = MTLSize(width: tnum, height: 1, depth: 1)
        let tgCnt = (grass.count / tnum) + 1
        let threadgroupCount = MTLSize(width: tgCnt, height: 1, depth: 1)
        enc.dispatchThreadgroups(threadgroupCount, threadsPerThreadgroup: threadsPerThreadgroup)
        
        enc.endEncoding()
        cmdBuff.popDebugGroup()
        
        cmdBuff.commit()
        cmdBuff.waitUntilCompleted()
    }
    
    func moveGrassAwayFromCharacter(_ charPos: Float3) {
        let modelMat = grass.transform.matrix
        let instanceDataPtr = grass.instanceDataBuff.contents().assumingMemoryBound(to: UpdateShearStrandData.self)
        var i=0; while i<grass.count { defer { i += 1 }
            let data = instanceDataPtr[i]
            let gpos = (modelMat * data.position.float4_w1).xyz
            let dv = gpos - charPos
            let d = length(dv)
            let dmax: Float = 0.4
            if d < dmax {
                var f = d / dmax
                f *= 0.5
                var newShear = mix(data.shear, dv*1.5, t: f)
                newShear.y = 0
                let transform = Transform(position: data.position, orientation: simd_quatf(vector: data.orientQuat), scale: data.scale, shear: newShear)
                instanceDataPtr[i].matrix = modelMat * transform.matrix
            }
        }
    }
}
