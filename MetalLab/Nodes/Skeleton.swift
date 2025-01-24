import Foundation
import ModelIO

class Skeleton {
    let skeleton: MDLSkeleton
    let jointInvBindMats: [float4x4] // model space to joint local space
    let jointRestMats: [float4x4] // poses of joints in local space of each joint
    var jointModelMats: [float4x4] // each joint in model space by applying parent joints transforms up to root
    var jointMats: [float4x4] // composite transforms model space to use in shaders
    let rootJoint: Joint
    let jointCount: Int
    //let parentIndices: [Int]
    var nodeMatrix: float4x4 = .identity
    
    init(skeleton: MDLSkeleton) {
        self.skeleton = skeleton
        self.jointInvBindMats = skeleton.jointBindTransforms.float4x4Array.map { $0.inverse }
        self.jointRestMats = skeleton.jointRestTransforms.float4x4Array
        self.rootJoint = Self.makeJoints(jointPaths: skeleton.jointPaths)
        self.jointCount = skeleton.jointPaths.count
        jointModelMats = .init(repeating: .identity, count: self.jointCount)
        jointMats = .init(repeating: .identity, count: self.jointCount)
        //self.parentIndices = Self.makeParentIndices(jointPaths: skeleton.jointPaths)
        //rootJoint.printTree()
        
        setRestPose()
    }
    
    static func makeJoints(jointPaths: [String]) -> Joint {
        let pathMap: [String.SubSequence: Joint] = jointPaths.enumerated().reduce(into: [:]) { partialMap, indexAndPath in
            let index = indexAndPath.offset
            let path = indexAndPath.element
            partialMap[path[...]] = Joint(path: path, index: index)
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
    
    func setRestPose() {
        setPose(jointLocalPoses: jointRestMats)
    }
    
    func setPose(jointLocalPoses: [float4x4]) {
        rootJoint.enumerateBFS { joint in
            if let parent = joint.parent {
                jointModelMats[joint.index] = jointModelMats[parent.index] * jointLocalPoses[joint.index]
            }
            else { // root
                jointModelMats[joint.index] = jointLocalPoses[joint.index]
            }
        }
        
        rootJoint.enumerateBFS { joint in
            jointMats[joint.index] = jointModelMats[joint.index] * jointInvBindMats[joint.index]
        }
    }
    
    func animate(animation: NodeAnimation) {
        
        let animTotalTime = Time.shared.current - animation.playStartTime
        let loopedTime = fmod(animTotalTime, animation.duration)
        let queryTime = loopedTime + animation.mdlBeginTime
        
        let ts = animation.jointAnim.translations.float3Array(atTime: queryTime)
        let rs = animation.jointAnim.rotations.floatQuaternionArray(atTime: queryTime)
        let ss = animation.jointAnim.scales.float3Array(atTime: queryTime)
        
        let animMats = zip(ts, zip(rs, ss)).map {
            let (t, (r, s)) = $0
            return float4x4.make(t: t, r: r, s: s)
        }
        
        // Animation can have a subset of skeleton paths (when it applies to only a few joints)
        var poses: [float4x4] = jointRestMats
        for (i, path) in skeleton.jointPaths.enumerated() {
            // is this joint in the animation
            if let animJointIndex = animation.jointAnim.jointPaths.firstIndex(of: path) {
                poses[i] = animMats[animJointIndex]
            }
        }
        
        setPose(jointLocalPoses: poses)
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

