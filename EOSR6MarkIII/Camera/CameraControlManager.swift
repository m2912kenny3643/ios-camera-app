import Foundation
import AVFoundation
import UIKit
import AVKit

class CameraControlManager {
    static let shared = CameraControlManager()
    
    weak var cameraService: CameraService?
    weak var settings: CameraSettings?
    
    // 初始化與註冊 iOS 17.2+ / iOS 18+ Camera Control 實體按鍵事件
    func attach(to view: UIView, cameraService: CameraService, settings: CameraSettings) {
        self.cameraService = cameraService
        self.settings = settings
        
        if #available(iOS 17.2, *) {
            let interaction = AVCaptureEventInteraction { [weak self] event in
                guard let self = self else { return }
                self.processCameraControlEvent(event)
            }
            view.addInteraction(interaction)
        }
    }
    
    @available(iOS 17.2, *)
    private func processCameraControlEvent(_ event: AVCaptureEvent) {
        switch event.phase {
        case .began:
            // 半按對焦 (Stage 1 / Half-Press)：鎖定 AF/AE，亮起綠色對焦框並發出 Canon 嗶聲
            cameraService?.lockFocusAndExposure()
            SoundManager.shared.playButtonFeedback()
            
        case .ended:
            // 全按快門 (Stage 2 / Full-Press)：釋放快門拍照
            cameraService?.capturePhoto()
            // 拍完後解除對焦鎖定
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.cameraService?.unlockFocusAndExposure()
            }
            
        case .cancelled:
            cameraService?.unlockFocusAndExposure()
            
        @unknown default:
            break
        }
    }
    
    // 轉盤滑動事件處理 (硬體電容滑動或螢幕轉盤)
    func handleDialValueChange(delta: CGFloat) {
        guard let settings = settings, let cameraService = cameraService else { return }
        
        switch settings.dialAssignment {
        case .zoom:
            let newZoom = max(1.0, min(15.0, settings.zoomFactor + delta * 0.05))
            cameraService.setZoom(newZoom)
            SoundManager.shared.playDialTick()
            
        case .exposureCompensation:
            let step = Double(round(delta * 3.0)) / 3.0 * 0.3
            let newEV = max(-3.0, min(3.0, settings.exposureCompensation + step))
            cameraService.setExposureCompensation(Float(newEV))
            SoundManager.shared.playDialTick()
            
        case .manualFocus:
            let newDist = max(0.0, min(1.0, settings.manualFocusDistance + Float(delta * 0.02)))
            settings.manualFocusDistance = newDist
            cameraService.setManualFocus(lensPosition: newDist)
            SoundManager.shared.playDialTick()
            
        case .pictureStyle:
            if abs(delta) > 0.5 {
                let allStyles = PictureStyleMode.allCases
                if let idx = allStyles.firstIndex(of: settings.pictureStyle) {
                    let nextIdx = delta > 0 ? (idx + 1) % allStyles.count : (idx - 1 + allStyles.count) % allStyles.count
                    settings.pictureStyle = allStyles[nextIdx]
                    SoundManager.shared.playDialTick()
                }
            }
        }
    }
}
