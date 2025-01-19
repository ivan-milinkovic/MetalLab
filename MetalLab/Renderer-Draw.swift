import Foundation
import simd
import Metal

extension Renderer {
    
    @MainActor
    func draw(scene: MyScene) {
        guard scene.isReady, let drawable = mtkView.currentDrawable, let commandBuffer = commandQueue.makeCommandBuffer()
        else { return }
        
        setupMsaaTextures() // there is no MTKView callback AFTER it changes size
        
        updateFrameConstants(scene)
        
        drawShadowMap(scene: scene, cmdBuff: commandBuffer)
        drawMain(scene: scene, cmdBuff: commandBuffer)

        //drawShadowMapDepthTexture(scene: scene, cmdBuff: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    func drawEnvironmentMap(enc: MTLRenderCommandEncoder) {
        
        let fc = frameConstantsBuff.contents().bindMemory(to: FrameConstants.self, capacity: 1)
        var invViewProjectMat = fc.pointee.viewProjectionMatrix.inverse
        
        enc.setRenderPipelineState(envMapPipelineState)
        enc.setFragmentBytes(&invViewProjectMat, length: MemoryLayout<float4x4>.stride, index: 0)
        enc.setFragmentTexture(cubeTex, index: 0)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    
    @MainActor
    func drawShadowMap(scene: MyScene, cmdBuff: MTLCommandBuffer)
    {
        cmdBuff.pushDebugGroup("Draw Shadow Map")
        
        let shadowRenderPassDesc = MTLRenderPassDescriptor()
        shadowRenderPassDesc.depthAttachment.loadAction = .clear
        shadowRenderPassDesc.depthAttachment.storeAction = .store
        shadowRenderPassDesc.depthAttachment.clearDepth = clearDepth
        shadowRenderPassDesc.depthAttachment.texture = scene.spotLight.texture
        
        let enc = cmdBuff.makeRenderCommandEncoder(descriptor: shadowRenderPassDesc)!
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        enc.setDepthStencilState(depthStencilState)
        
        enc.setRenderPipelineState(shadowTessPipelineState)
        encodeTesselatedGeometry(scene: scene, encoder: enc)
        
        enc.setRenderPipelineState(shadowPipelineState)
        encodeRegularGeometry(scene: scene, encoder: enc)
        encodeTransparentGeometry(scene: scene, encoder: enc)
        
        enc.endEncoding()
        cmdBuff.popDebugGroup()
    }
    
    
    @MainActor
    func drawMain(scene: MyScene, cmdBuff: MTLCommandBuffer) {
        cmdBuff.pushDebugGroup("Main Render Pass")
        let renderPassDesc = mainRenderPassDescriptor()
        guard let enc = cmdBuff.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }
        
        enc.setTriangleFillMode(triangleFillMode)
        
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        enc.setDepthStencilState(depthStencilState)
        
        drawEnvironmentMap(enc: enc)
        
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        
        enc.setRenderPipelineState(tesselationPipelineState)
        encodeTesselatedGeometry(scene: scene, encoder: enc)
        
        enc.setRenderPipelineState(mainPipelineState)
        encodeRegularGeometry(scene: scene, encoder: enc)
        encodeAnimatedGeometry(scene: scene, encoder: enc)
        encodeTransparentGeometry(scene: scene, encoder: enc)
        
        enc.endEncoding()
        cmdBuff.popDebugGroup()
    }
    
    func encodeRegularGeometry(scene: MyScene, encoder: MTLRenderCommandEncoder) {
        
        encoder.setVertexBuffer(frameConstantsBuff, offset: 0, index: 2)
        encoder.setFragmentBuffer(frameConstantsBuff, offset: 0, index: 0)
        
        for meshObject in scene.regularObjects {
            
            meshObject.updateConstantsBuffer()
            let instanceCount = meshObject.instanceCount()
            
            encoder.setVertexBuffer(meshObject.metalMesh.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(meshObject.objectConstantsBuff, offset: 0, index: 1)
            encoder.setFragmentTexture(meshObject.metalMesh.texture, index: 0)
            encoder.setFragmentTexture(scene.spotLight.texture, index: 1)
            encoder.setFragmentTexture(cubeTex, index: 2)
            encoder.setFragmentTexture(meshObject.metalMesh.normalMap, index: 3)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: meshObject.metalMesh.vertexCount, instanceCount: instanceCount)
        }
    }
    
    func encodeAnimatedGeometry(scene: MyScene, encoder: MTLRenderCommandEncoder) {
        guard let obj = scene.animMesh else { return }
        encoder.setVertexBuffer(obj.mtkVertexBuffer.buffer, offset: obj.mtkVertexBuffer.offset, index: 0)
        encoder.setVertexBuffer(obj.objectConstantsBuff, offset: 0, index: 1)
        encoder.setFragmentTexture(scene.spotLight.texture, index: 1)
        //encoder.setFragmentTexture(obj.texture, index: 0)
        //encoder.setFragmentTexture(cubeTex, index: 2)
        //encoder.setFragmentTexture(obj.normalMap, index: 3)
        
        encoder.drawIndexedPrimitives(type: obj.geometryType,
                                      indexCount: obj.indexCount,
                                      indexType: obj.indexType,
                                      indexBuffer: obj.mtkIndexBuffer.buffer,
                                      indexBufferOffset: obj.mtkIndexBuffer.offset)
    }
    
    func encodeTransparentGeometry(scene: MyScene, encoder: MTLRenderCommandEncoder) {
        
        encoder.setVertexBuffer(frameConstantsBuff, offset: 0, index: 2)
        encoder.setFragmentBuffer(frameConstantsBuff, offset: 0, index: 0)
        
        for meshObject in scene.transparentObjects {
            
            meshObject.updateConstantsBuffer()
            let instanceCount = meshObject.instanceCount()
            
            encoder.setVertexBuffer(meshObject.metalMesh.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(meshObject.objectConstantsBuff, offset: 0, index: 1)
            encoder.setFragmentTexture(meshObject.metalMesh.texture, index: 0)
            encoder.setFragmentTexture(scene.spotLight.texture, index: 1)
            encoder.setFragmentTexture(cubeTex, index: 2)
            encoder.setFragmentTexture(meshObject.metalMesh.normalMap, index: 3)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: meshObject.metalMesh.vertexCount, instanceCount: instanceCount)
        }
    }
    
    // https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Tessellation/Tessellation.html#//apple_ref/doc/uid/TP40014221-CH15
    
    @MainActor
    func encodeTesselatedGeometry(scene: MyScene, encoder enc: MTLRenderCommandEncoder) {
        for meshObject in scene.tessObjects {
            guard let tessellationFactorsBuff = meshObject.tessellationFactorsBuff else { continue }
            
            meshObject.updateConstantsBuffer()
            
            enc.setVertexBuffer(frameConstantsBuff, offset: 0, index: 2)
            enc.setFragmentBuffer(frameConstantsBuff, offset: 0, index: 0)
            
            enc.setVertexBuffer(meshObject.metalMesh.vertexBuffer, offset: 0, index: 0)
            enc.setVertexBuffer(meshObject.objectConstantsBuff, offset: 0, index: 1)
            enc.setVertexTexture(meshObject.metalMesh.displacementMap, index: 0)
            enc.setVertexSamplerState(textureSamplerState, index: 0)
            
            enc.setFragmentTexture(meshObject.metalMesh.texture, index: 0)
            enc.setFragmentTexture(scene.spotLight.texture, index: 1)
            enc.setFragmentTexture(cubeTex, index: 2)
            enc.setFragmentTexture(meshObject.metalMesh.normalMap, index: 3)
            
            enc.setTessellationFactorBuffer(tessellationFactorsBuff, offset: 0, instanceStride: 0)
            
            let patchCount = meshObject.metalMesh.vertexCount / 3
            enc.drawPatches(numberOfPatchControlPoints: 3,
                            patchStart: 0,
                            patchCount: patchCount,
                            patchIndexBuffer: nil,
                            patchIndexBufferOffset: 0,
                            instanceCount: 1,
                            baseInstance: 0)
        }
    }
    
    
    @MainActor
    func drawShadowMapDepthTexture(scene: MyScene, cmdBuff: MTLCommandBuffer) {
        let pipeline = MTLRenderPipelineDescriptor()
        pipeline.vertexDescriptor = VertexData.vertexDescriptor
        pipeline.vertexFunction = library.makeFunction(name: "vertex_depth_show")
        pipeline.fragmentFunction = library.makeFunction(name: "fragment_depth_show")
        pipeline.colorAttachments[0].pixelFormat = colorPixelFormat
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].loadAction = .load
        renderPass.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        renderPass.colorAttachments[0].texture = mtkView.currentDrawable!.texture
        let pipelineState = try! device.makeRenderPipelineState(descriptor: pipeline)
        
        var vertices: [Float2] = [
            [-1,  1],
            [-1, -1],
            [ 1, -1],
            [-1,  1],
            [ 1, -1],
            [ 1,  1]
        ]
        let aspect = Float(mtkView.drawableSize.width / mtkView.drawableSize.height)
        let wscale = 0.25/aspect
        let scaleMat = float2x2([wscale, 0], [0, 0.25])
        vertices = vertices.map { v in
            scaleMat * v + [-(1-wscale), 0.75]
        }
        let vbuff = device.makeBuffer(bytes: &vertices,length: MemoryLayout<SIMD2<Float>>.stride * vertices.count, options: .storageModeShared)
        
        var uvs: [Float2] = [
            [0.0,  0.0],
            [0.0,  1.0],
            [1.0,  1.0],
            [0.0,  0.0],
            [1.0,  1.0],
            [1.0,  0.0]
        ]
        let uvbuff = device.makeBuffer(bytes: &uvs,length: MemoryLayout<SIMD2<Float>>.stride * uvs.count, options: .storageModeShared)
        
        let enc = cmdBuff.makeRenderCommandEncoder(descriptor: renderPass)!
        enc.setFrontFacing(winding)
        enc.setCullMode(.back)
        enc.setRenderPipelineState(pipelineState)
        enc.setVertexBuffer(vbuff, offset: 0, index: 0)
        enc.setVertexBuffer(uvbuff, offset: 0, index: 1)
        enc.setFragmentSamplerState(textureSamplerState, index: 0)
        enc.setFragmentTexture(scene.spotLight.texture, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        enc.endEncoding()
    }
    
    func updateFrameConstants(_ scene: MyScene) {
        let viewMatrix = scene.camera.viewMatrix
        //let viewMatrix = scene.spotLight.transform.transform.inverse // render scene from light perspective
        
        let fc = frameConstantsBuff.contents().bindMemory(to: FrameConstants.self, capacity: 1)
        fc.pointee.viewMatrix = viewMatrix
        fc.pointee.projectionMatrix = scene.camera.projectionMatrix
        fc.pointee.viewProjectionMatrix = fc.pointee.projectionMatrix * fc.pointee.viewMatrix
        
        let dirLight = fc.pointee.viewMatrix * scene.directionalLightDir.float4_w0
        fc.pointee.directionalLightDir = dirLight.xyz
        
        let lightMatrix = scene.spotLight.position.matrix.inverse
        fc.pointee.lightProjectionMatrix = scene.shadowMapProjectionMatrix * lightMatrix
        
        let lightPos = viewMatrix * scene.spotLight.position.position.float4_w1 // position in view space
        let lightDir = viewMatrix.inverse.transpose * scene.spotLight.position.orientation.axis.float4_w0
        fc.pointee.spotLight.position = lightPos.xyz
        fc.pointee.spotLight.direction = lightDir.xyz
        fc.pointee.spotLight.color = scene.spotLight.color
    }
}
