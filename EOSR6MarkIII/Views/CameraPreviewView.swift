import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let cameraService: CameraService
    let settings: CameraSettings
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(session: session)
        
        // 綁定手勢與 Camera Control
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        if uiView.previewLayer.session != session {
            uiView.previewLayer.session = session
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(cameraService: cameraService, settings: settings)
    }
    
    class Coordinator: NSObject {
        let cameraService: CameraService
        let settings: CameraSettings
        
        init(cameraService: CameraService, settings: CameraSettings) {
            self.cameraService = cameraService
            self.settings = settings
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            guard let view = gesture.view else { return }
            
            let normalizedPoint = CGPoint(
                x: location.x / view.bounds.width,
                y: location.y / view.bounds.height
            )
            
            settings.afPointNormalized = normalizedPoint
            cameraService.lockFocusAndExposure(at: normalizedPoint)
        }
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
