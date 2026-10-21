import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var roll: Double = 0.0
    @Published var pitch: Double = 0.0
    @Published var isLevel: Bool = false
    
    init() {
        startMotionUpdates()
    }
    
    deinit {
        stopMotionUpdates()
    }
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0 // 30Hz
        
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            // 根據相機橫向取景 (Landscape) 與直向取景調整 Roll / Pitch
            let gravity = motion.gravity
            
            // 計算水平傾斜角度 (Roll in degrees)
            let rollDegrees = atan2(gravity.x, -gravity.y) * 180.0 / .pi
            let pitchDegrees = atan2(gravity.z, sqrt(gravity.x * gravity.x + gravity.y * gravity.y)) * 180.0 / .pi
            
            self.roll = rollDegrees
            self.pitch = pitchDegrees
            
            // 當誤差在 ±0.8 度以內時視為絕對水平 (綠色標尺)
            let normalizedRoll = abs(rollDegrees).truncatingRemainder(dividingBy: 90.0)
            self.isLevel = normalizedRoll < 0.8 || abs(normalizedRoll - 90.0) < 0.8
        }
    }
    
    func stopMotionUpdates() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }
}
