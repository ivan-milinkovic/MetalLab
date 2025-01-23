import Foundation
import ModelIO

struct Skeleton {
    let skeleton: MDLSkeleton
    let jointModelToLocalMats: [float4x4]
    let jointLocalRestMats: [float4x4]
    var jointModelMats: [float4x4]
    let rootJoint: Joint
    //let parentIndices: [Int]
    
    init(skeleton: MDLSkeleton) {
        self.skeleton = skeleton
        self.jointModelToLocalMats = skeleton.jointBindTransforms.float4x4Array.map { $0.inverse }
        self.jointLocalRestMats = skeleton.jointRestTransforms.float4x4Array
        self.rootJoint = Self.makeJoints(jointPaths: skeleton.jointPaths)
        jointModelMats = .init(repeating: .identity, count: skeleton.jointPaths.count)
        //self.parentIndices = Self.makeParentIndices(jointPaths: skeleton.jointPaths)
        //rootJoint.printTree()
    }
    
    static func makeJoints(jointPaths: [String]) -> Joint {
        let pathMap: [String.SubSequence: Joint] = jointPaths.reduce(into: [:]) { partialMap, path in
            partialMap[path[...]] = Joint(path: path)
        }
        
        pathMap.forEach { (path, joint) in
            if let lastSlashIndex = path.lastIndex(of: "/") {
                let parentPath = path[path.startIndex..<lastSlashIndex]
                let parentJoint = pathMap[parentPath]
                joint.parent = parentJoint
                parentJoint?.children.append(joint)
            }
        }
        
        let rootJoint = pathMap.first( where: { (_, joint) in joint.parent == nil })!.value
        
        return rootJoint
    }
    
    func animate(anim: NodeAnimation) {
        // calcualte jointModelMats here
    }
    
    /// Calculate an array where each entry is an index of the parent
    static func makeParentIndices(jointPaths: [String]) -> [Int] {
        
        var parentIndices = [Int].init(repeating: -1, count: jointPaths.count)
        var pathMap: [String.SubSequence: PathInfo] = [:]
        
        for (pathIndex, path) in jointPaths.enumerated() {
            let pathInfo = PathInfo.make(path: path, pathIndex: pathIndex)
            let pathSeq = path[...]
            pathMap[pathSeq] = pathInfo
        }
        
        for (_, pathInfo) in pathMap {
            let pathIndex = pathInfo.pathIndex
            let parentIndex = pathMap[pathInfo.parentPath]?.pathIndex ?? -1 // the root doesn't have a parent
            parentIndices[pathIndex] = parentIndex
        }
        
        return parentIndices
    }
    
    private struct PathInfo {
        let path: String.SubSequence
        let pathIndex: Int
        let parentPath: String.SubSequence
        
        init(path: String.SubSequence, pathIndex: Int, parentPath: String.SubSequence) {
            self.path = path
            self.pathIndex = pathIndex
            self.parentPath = parentPath
        }
        
        static func make(path: String, pathIndex: Int) -> PathInfo {
            var parentPath: String.SubSequence = ""
            if let lastSlashIndex = path.lastIndex(of: "/") {
                parentPath = path[path.startIndex..<lastSlashIndex]
            }
            return PathInfo(path: path[...], pathIndex: pathIndex, parentPath: parentPath)
        }
    }
}

