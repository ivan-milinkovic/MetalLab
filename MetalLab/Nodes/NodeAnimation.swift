import ModelIO

class NodeAnimation {
    
    let mdlAnimComponent: MDLAnimationBindComponent
    let jointAnim: MDLPackedJointAnimation
    
    let mdlBeginTime: TimeInterval
    let mdlEndTime: TimeInterval
    var playStartTime: TimeInterval = 0.0
    var duration: TimeInterval
    
    init?(mdlAnimComponent: MDLAnimationBindComponent) {
        self.mdlAnimComponent = mdlAnimComponent
        guard let jointAnim = mdlAnimComponent.jointAnimation as? MDLPackedJointAnimation else { return nil }
        self.jointAnim = jointAnim
        
        var mdlMinTime = min(jointAnim.translations.minimumTime,
                           jointAnim.rotations.minimumTime)
        mdlMinTime = min(jointAnim.scales.minimumTime, mdlMinTime)
        
        var mdlMaxTime = max(jointAnim.translations.maximumTime,
                           jointAnim.rotations.maximumTime)
        mdlMaxTime = max(jointAnim.scales.maximumTime, mdlMaxTime)
        
        mdlBeginTime = mdlMinTime
        mdlEndTime = mdlMaxTime
        duration = mdlEndTime - mdlBeginTime
    }
    
    func markStart() {
        playStartTime = Time.shared.current
    }
    
    func markStop() {
        playStartTime = 0.0
    }
}
