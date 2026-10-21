import Foundation
import AudioToolbox
import AVFoundation
import UIKit

class SoundManager {
    static let shared = SoundManager()
    
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let lightImpactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private var audioPlayer: AVAudioPlayer?
    
    init() {
        impactFeedback.prepare()
        lightImpactFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // 撥輪刻度反饋 (轉盤齒輪感)
    func playDialTick() {
        lightImpactFeedback.impactOccurred(intensity: 0.7)
    }
    
    // Canon 經典合焦確認音 (雙音節嗶嗶聲) + 綠框觸覺
    func playFocusLocked() {
        notificationFeedback.notificationOccurred(.success)
        
        // 播放系統提示音 (類似相機合焦嗶聲的清脆短音)
        AudioServicesPlaySystemSound(1057) // PIN / SMS alert tone or focus beep
    }
    
    // Canon 快門釋放震動與快門音
    func playShutterSound() {
        // 模擬機械快門震動感
        let heavyFeedback = UIImpactFeedbackGenerator(style: .rigid)
        heavyFeedback.impactOccurred(intensity: 1.0)
        
        // 播放快門音效 (SystemSoundID 1108 為 iOS 經典相機快門音)
        AudioServicesPlaySystemSound(1108)
    }
    
    // 按鈕按壓觸覺
    func playButtonFeedback() {
        impactFeedback.impactOccurred(intensity: 0.8)
    }
}
