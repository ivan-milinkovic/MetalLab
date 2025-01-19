import Metal
import ModelIO

extension MTLPackedFloat3: @retroactive CustomStringConvertible {
    public var description: String {
        "(\(x), \(y), \(z)"
    }
}

extension MDLVertexDescriptor {
    var mdlVertexAttributes: [MDLVertexAttribute] {
        return attributes as! [MDLVertexAttribute]
    }

    var mdlBufferLayouts: [MDLVertexBufferLayout] {
        return layouts as! [MDLVertexBufferLayout]
    }
}

func mtlPrimitiveType(fromMdl mdlGeomType: MDLGeometryType) -> MTLPrimitiveType? {
    switch mdlGeomType{
    case .points: .point
    case .lines: .line
    case .triangles: .triangle
    case .triangleStrips: .triangleStrip
    default: nil
    }
}

func mtlIndexType(fromMdl mdlIndexType: MDLIndexBitDepth) -> MTLIndexType? {
    switch mdlIndexType {
    case .uInt16 : .uint16
    case .uInt32 : .uint32
    default: nil
    }
}
