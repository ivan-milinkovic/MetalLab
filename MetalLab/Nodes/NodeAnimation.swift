import ModelIO

struct NodeAnimation {
    let mdlAnimComponent: MDLAnimationBindComponent
    let jointAnim: MDLPackedJointAnimation
    init?(mdlAnimComponent: MDLAnimationBindComponent) {
        self.mdlAnimComponent = mdlAnimComponent
        guard let jointAnim = mdlAnimComponent.jointAnimation as? MDLPackedJointAnimation else { return nil }
        self.jointAnim = jointAnim
    }
}
