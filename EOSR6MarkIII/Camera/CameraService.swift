import Foundation
import AVFoundation
import UIKit
import Photos
import CoreImage

class CameraService: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var session = AVCaptureSession()
    
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    private let sessionQueue = DispatchQueue(label: "tw.neofocus.camera.sessionQueue")
    private let ciContext = CIContext()
    
    var settings: CameraSettings?
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupSession()
                }
            }
        default:
            break
        }
    }
    
    func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            
            // 優先選擇具備超廣角、廣角、長焦的三鏡頭相機模組 (Triple / Dual Camera)
            let deviceTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInWideAngleCamera
            ]
            
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: .back
            )
            
            guard let camera = discoverySession.devices.first else {
                self.session.commitConfiguration()
                return
            }
            
            self.currentDevice = camera
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    self.photoOutput.isHighResolutionCaptureEnabled = true
                    if self.photoOutput.isResponsiveCaptureSupported {
                        self.photoOutput.isResponsiveCaptureEnabled = true // Zero shutter lag
                    }
                }
                
                self.session.commitConfiguration()
                self.session.startRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                }
            } catch {
                self.session.commitConfiguration()
                print("相機輸入配置失敗: \(error)")
            }
        }
    }
    
    // MARK: - 對焦控制 (AF Lock / Unlock / Tap to Focus)
    func lockFocusAndExposure(at point: CGPoint? = nil) {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            let targetPoint = point ?? CGPoint(x: 0.5, y: 0.5)
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = targetPoint
            }
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = targetPoint
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.settings?.isAFLocked = true
                self.settings?.isAFGreen = true
                SoundManager.shared.playFocusLocked()
            }
        } catch {
            print("無法鎖定對焦: \(error)")
        }
    }
    
    func unlockFocusAndExposure() {
        guard let device = currentDevice else { return }
        
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.settings?.isAFLocked = false
                self.settings?.isAFGreen = false
            }
        } catch {
            print("無法重設對焦: \(error)")
        }
    }
    
    // 手動對焦距離 (0.0 近處 ... 1.0 無限遠)
    func setManualFocus(lensPosition: Float) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.locked) {
                device.setFocusModeLocked(lensPosition: max(0.0, min(1.0, lensPosition)), completionHandler: nil)
            }
            device.unlockForConfiguration()
        } catch {
            print("手動對焦錯誤: \(error)")
        }
    }
    
    // MARK: - 變焦控制 (Zoom)
    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            let clamped = max(device.minAvailableVideoZoomFactor, min(device.maxAvailableVideoZoomFactor, factor))
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.settings?.zoomFactor = clamped
            }
        } catch {
            print("變焦設定失敗: \(error)")
        }
    }
    
    // MARK: - 曝光補償 (EV Bias)
    func setExposureCompensation(_ bias: Float) {
        guard let device = currentDevice else { return }
        do {
            try device.lockForConfiguration()
            let clampedBias = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, bias))
            device.setExposureTargetBias(clampedBias, completionHandler: nil)
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.settings?.exposureCompensation = Double(clampedBias)
            }
        } catch {
            print("曝光補償設定失敗: \(error)")
        }
    }
    
    // MARK: - 快門拍攝 (Capture Photo)
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.isHighResolutionPhotoEnabled = true
            
            DispatchQueue.main.async {
                SoundManager.shared.playShutterSound()
            }
            
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), var uiImage = UIImage(data: data) else {
            print("拍攝影像處理錯誤: \(String(describing: error))")
            return
        }
        
        // 套用目前設定的 Canon Picture Style (相片風格)
        if let currentStyle = self.settings?.pictureStyle, let ciImage = CIImage(image: uiImage) {
            let filteredCIImage = currentStyle.apply(to: ciImage)
            if let cgImage = self.ciContext.createCGImage(filteredCIImage, from: filteredCIImage.extent) {
                uiImage = UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: uiImage.imageOrientation)
            }
        }
        
        // 儲存至系統相簿
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
        }) { success, error in
            if success {
                DispatchQueue.main.async {
                    self.settings?.lastCapturedImage = uiImage
                    if let remaining = self.settings?.remainingShots, remaining > 0 {
                        self.settings?.remainingShots = remaining - 1
                    }
                }
            } else if let error = error {
                print("寫入相簿失敗: \(error)")
            }
        }
    }
}
