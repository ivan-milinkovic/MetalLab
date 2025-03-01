import Metal
import MetalKit
import ModelIO

/// Easier access to mesh properties and conversion from MDL to MTK models
struct NodeMesh {
    let mesh: MDLMesh
    let submeshes: [SubMesh]
    let objectConstantsBuff: MTLBuffer
    let mtkMeshBuffer: MTKMeshBuffer
    
    init(mesh: MDLMesh, device: MTLDevice) {
        loadTangents(mesh)
        self.mesh = mesh
        self.mtkMeshBuffer = mesh.vertexBuffers.first as! MTKMeshBuffer // VertexData.makeModelioVertexDescriptor() defines a single buffer
        var objConstantsPrototype = ObjectConstants()
        objectConstantsBuff = device.makeBuffer(bytes: &objConstantsPrototype, length: MemoryLayout<ObjectConstants>.stride, options: .storageModeShared)!
        let mdlSubmeshes = mesh.submeshes as! [MDLSubmesh] // has to have at least one
        self.submeshes = readSubmeshes(mdlSubmeshes: mdlSubmeshes, device: device)
    }
}

struct SubMesh {
    let mdlSubmesh: MDLSubmesh
    let material: Material
}

private func loadTangents(_ mesh: MDLMesh) {
    mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                         normalAttributeNamed: MDLVertexAttributeNormal,
                         tangentAttributeNamed: MDLVertexAttributeTangent)
    mesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                         tangentAttributeNamed: MDLVertexAttributeTangent,
                         bitangentAttributeNamed: MDLVertexAttributeBitangent)
}

extension CGColor {
    func float4(_ colorSpace: CGColorSpace) -> Float4 {
        guard let converted = self.converted(to: colorSpace, intent: .defaultIntent, options: nil),
              let comps = converted.components else {
            return .one
        }
        let fcomps = comps.map { Float($0) }
        return Float4(fcomps)
    }
}

private func readSubmeshes(mdlSubmeshes: [MDLSubmesh], device: MTLDevice) -> [SubMesh] {
    let texOpts: [MTKTextureLoader.Option : Any] = [
        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        .textureStorageMode: MTLStorageMode.private.rawValue,
        .origin : MTKTextureLoader.Origin.flippedVertically,
        .generateMipmaps : true,
    ]
    let texLoader = MTKTextureLoader(device: device)
    
    let submeshes = mdlSubmeshes.map { mdlSubmesh in
        let material = readMaterial(mdlSubmesh.material, texLoader: texLoader, texOpts: texOpts)
        return SubMesh(mdlSubmesh: mdlSubmesh, material: material)
    }
    
    return submeshes
}

private func readMaterial(_ mdlMaterial: MDLMaterial?,
                          texLoader: MTKTextureLoader,
                          texOpts: [MTKTextureLoader.Option : Any]) -> Material {
    
    guard let mdlMaterial else { return Material() }
    
    var mat = Material()
    let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
    
    // TODO: don't load textures more than once
    
    let colorTexOpts = texOpts.merging([.SRGB: true], uniquingKeysWith: { $1 })
    
    // Base color
    if let colorProp = mdlMaterial.property(with: .baseColor) {
        switch colorProp.type {
        case .float: mat.color = Float4(colorProp.floatValue, colorProp.floatValue, colorProp.floatValue, 1)
        case .float3: mat.color = Float4(colorProp.float3Value, 1)
        case .float4: mat.color = colorProp.float4Value
        
        case .color:
            let cgColor = colorProp.color ?? CGColor.white
            mat.color = cgColor.float4(colorSpace)
            
        case .texture:
            if let mdlTexture = colorProp.textureSamplerValue?.texture {
                do {
                    let texture = try texLoader.newTexture(texture: mdlTexture, options: colorTexOpts)
                    mat.colorTexture = texture
                } catch {
                    print("NodeMesh: error loading base color texture:", error)
                }
            }
        default:
            break
        }
    }
    
    
    // Emissive color
    if let emissiveProp = mdlMaterial.property(with: .emission) {
        switch emissiveProp.type {
        case .float:  mat.emissiveColor = Float3(repeating: emissiveProp.floatValue)
        case .float3: mat.emissiveColor = emissiveProp.float3Value
        case .float4: mat.emissiveColor = emissiveProp.float4Value.xyz
            
        case .color:
            let cgColor = emissiveProp.color ?? CGColor.white
            let col = cgColor.float4(colorSpace)
            mat.emissiveColor = col.xyz
            
        case .texture:
            if let mdlTexture = emissiveProp.textureSamplerValue?.texture {
                do {
                    let texture = try texLoader.newTexture(texture: mdlTexture, options: colorTexOpts)
                    mat.emissiveTexture = texture
                    texture.label = "Emissive Texture"
                } catch {
                    print("NodeMesh: error loading emissive color texture:", error)
                }
            }
        default:
            break
        }
    }
        
        
    // Opacity
    if let opacityProp = mdlMaterial.property(with: .opacity),
       opacityProp.type == .float
    {
        mat.opacity = opacityProp.floatValue
    }
    
    
    // Normal map
    if let normalProp = mdlMaterial.property(with: .tangentSpaceNormal),
       normalProp.type == .texture,
       let mdlNormalTexture = normalProp.textureSamplerValue?.texture
    {
        do {
            let normalTex = try texLoader.newTexture(texture: mdlNormalTexture, options: texOpts)
            mat.normalTexture = normalTex
        } catch {
            print("NodeMesh: error loading normal map texture:", error)
        }
    }
    
    
    // Roughness
    if let roughnessProp = mdlMaterial.property(with: .roughness) {
        switch roughnessProp.type {
        case .float:
            mat.roughness = roughnessProp.floatValue
        case .texture:
            if let mdlRoughnessTex = roughnessProp.textureSamplerValue?.texture {
                do {
                    let roughnessTex = try texLoader.newTexture(texture: mdlRoughnessTex, options: texOpts)
                    mat.roughnessTexture = roughnessTex
                } catch {
                    print("NodeMesh: error loading roughness texture:", error)
                }
            }
        default: break
        }
    }
    
    // Metalness
    if let metalnessProp = mdlMaterial.property(with: .metallic) {
        switch metalnessProp.type {
        case .float:
            mat.metalness = metalnessProp.floatValue
        case .texture:
            if let mdlMetalnessTex = metalnessProp.textureSamplerValue?.texture {
                do {
                    let metalnessTex = try texLoader.newTexture(texture: mdlMetalnessTex, options: texOpts)
                    mat.metalnessTexture = metalnessTex
                } catch {
                    print("NodeMesh: error loading metalness texture:", error)
                }
            }
        default: break
        }
    }
    
    // Ambient occlusion
    if let occlusionProp = mdlMaterial.property(with: .ambientOcclusion),
       occlusionProp.type == .texture,
       let mdlOcclusionTex = occlusionProp.textureSamplerValue?.texture
    {
        do {
            mat.ambOcclusionTexture = try texLoader.newTexture(texture: mdlOcclusionTex, options: texOpts)
        } catch {
            print("NodeMesh: error loading ambient occlusion texture:", error)
        }
    }
    
    
    //if let ambScaleProp = mdlMaterial.property(with: .ambientOcclusionScale) {
    //    // TODO: read ambientOcclusionScale
    //}
    
    return mat
}
