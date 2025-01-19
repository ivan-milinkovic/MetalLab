import Metal
import ModelIO

extension MTLPackedFloat3: @retroactive CustomStringConvertible {
    public var description: String {
        "(\(x), \(y), \(z)"
    }
}

extension MDLVertexDescriptor {
    var vertexAttributes: [MDLVertexAttribute] {
        return attributes as! [MDLVertexAttribute]
    }

    var bufferLayouts: [MDLVertexBufferLayout] {
        return layouts as! [MDLVertexBufferLayout]
    }
}
