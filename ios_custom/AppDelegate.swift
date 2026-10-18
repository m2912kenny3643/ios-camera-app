import UIKit
import Flutter
import Vision
import CoreMedia

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var sequenceHandler = VNSequenceRequestHandler()
  private var currentTrackRequest: VNTrackObjectRequest?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let visionChannel = FlutterMethodChannel(name: "tw.neofocus/vision",
                                              binaryMessenger: controller.binaryMessenger)
    
    visionChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      
      if call.method == "detectAnimalPose" {
        guard let args = call.arguments as? [String: Any],
              let bytesData = (args["bytes"] as? FlutterStandardTypedData)?.data,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int else {
          result(nil)
          return
        }
        self.processAnimalVision(data: bytesData, width: width, height: height, result: result)
        
      } else if call.method == "lockTarget" {
        guard let args = call.arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double,
              let w = args["w"] as? Double,
              let h = args["h"] as? Double else {
          result(false)
          return
        }
        // Apple Vision coordinates: origin is bottom-left, normalized [0, 1]
        let visionRect = CGRect(x: x, y: max(0.0, 1.0 - y - h), width: min(1.0, w), height: min(1.0, h))
        let initObservation = VNDetectedObjectObservation(boundingBox: visionRect)
        let trackReq = VNTrackObjectRequest(detectedObjectObservation: initObservation)
        trackReq.trackingLevel = .fast
        self.currentTrackRequest = trackReq
        result(true)
        
      } else if call.method == "trackLockedTarget" {
        guard let args = call.arguments as? [String: Any],
              let bytesData = (args["bytes"] as? FlutterStandardTypedData)?.data,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int,
              let trackReq = self.currentTrackRequest else {
          result(nil)
          return
        }
        self.processOpticalTrack(data: bytesData, width: width, height: height, request: trackReq, result: result)
        
      } else if call.method == "cancelLock" {
        self.currentTrackRequest = nil
        result(true)
        
      } else {
        result(FlutterMethodNotImplemented)
      }
    })

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 1. Apple Neural Engine (ANE) 鳥類/動物骨架與眼部識別
  private func processAnimalVision(data: Data, width: Int, height: Int, result: @escaping FlutterResult) {
    guard let pixelBuffer = self.createPixelBuffer(from: data, width: width, height: height) else {
      result(nil)
      return
    }

    if #available(iOS 14.0, *) {
      let animalPoseRequest = VNDetectAnimalBodyPoseRequest { [weak self] request, error in
        guard error == nil,
              let observations = request.results as? [VNAnimalBodyPoseObservation],
              let topObs = observations.first else {
          // 若未偵測到骨架，回退至一般動物/鳥類檢測
          self?.runAnimalDetectionFallback(buffer: pixelBuffer, result: result)
          return
        }

        var eyeDict: [String: Double]? = nil
        if let points = try? topObs.recognizedPoints(.all) {
          // 優先選取左眼或右眼
          if let leftEye = points[VNAnimalBodyPoseObservation.JointName.leftEye], leftEye.confidence > 0.3 {
            eyeDict = ["x": Double(leftEye.location.x), "y": Double(1.0 - leftEye.location.y)]
          } else if let rightEye = points[VNAnimalBodyPoseObservation.JointName.rightEye], rightEye.confidence > 0.3 {
            eyeDict = ["x": Double(rightEye.location.x), "y": Double(1.0 - rightEye.location.y)]
          } else if let head = points[VNAnimalBodyPoseObservation.JointName.neck], head.confidence > 0.3 {
            eyeDict = ["x": Double(head.location.x), "y": Double(1.0 - head.location.y)]
          }
        }

        let box = topObs.boundingBox
        let payload: [String: Any] = [
          "detected": true,
          "label": "鳥類/動物",
          "x": Double(box.origin.x),
          "y": Double(max(0.0, 1.0 - box.origin.y - box.size.height)),
          "w": Double(box.size.width),
          "h": Double(box.size.height),
          "eye": eyeDict as Any,
          "confidence": Double(topObs.confidence)
        ]
        DispatchQueue.main.async { result(payload) }
      }

      let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
      DispatchQueue.global(qos: .userInteractive).async {
        do {
          try handler.perform([animalPoseRequest])
        } catch {
          DispatchQueue.main.async { result(nil) }
        }
      }
    } else {
      self.runAnimalDetectionFallback(buffer: pixelBuffer, result: result)
    }
  }

  // 動物與鳥類物件辨識回退
  private func runAnimalDetectionFallback(buffer: CVPixelBuffer, result: @escaping FlutterResult) {
    if #available(iOS 13.0, *) {
      let animalRequest = VNRecognizeAnimalsRequest { request, error in
        guard error == nil,
              let observations = request.results as? [VNRecognizedObjectObservation],
              let topAnimal = observations.first else {
          DispatchQueue.main.async { result(nil) }
          return
        }

        let box = topAnimal.boundingBox
        let rawLabel = topAnimal.labels.first?.identifier ?? "動物"
        let label = rawLabel == "Bird" ? "鳥類" : (rawLabel == "Cat" || rawLabel == "Dog" ? "動物" : rawLabel)

        let payload: [String: Any] = [
          "detected": true,
          "label": label,
          "x": Double(box.origin.x),
          "y": Double(max(0.0, 1.0 - box.origin.y - box.size.height)),
          "w": Double(box.size.width),
          "h": Double(box.size.height),
          "confidence": Double(topAnimal.confidence)
        ]
        DispatchQueue.main.async { result(payload) }
      }

      let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:])
      DispatchQueue.global(qos: .userInteractive).async {
        do {
          try handler.perform([animalRequest])
        } catch {
          DispatchQueue.main.async { result(nil) }
        }
      }
    } else {
      DispatchQueue.main.async { result(nil) }
    }
  }

  // 2. Apple Neural Engine 高速光流目標鎖定追蹤 (60fps)
  private func processOpticalTrack(data: Data, width: Int, height: Int, request: VNTrackObjectRequest, result: @escaping FlutterResult) {
    guard let pixelBuffer = self.createPixelBuffer(from: data, width: width, height: height) else {
      result(nil)
      return
    }

    DispatchQueue.global(qos: .userInteractive).async { [weak self] in
      guard let self = self else { return }
      do {
        try self.sequenceHandler.perform([request], on: pixelBuffer, orientation: .right)
        if let observation = request.results?.first as? VNDetectedObjectObservation {
          let box = observation.boundingBox
          let payload: [String: Any] = [
            "locked": true,
            "x": Double(box.origin.x),
            "y": Double(max(0.0, 1.0 - box.origin.y - box.size.height)),
            "w": Double(box.size.width),
            "h": Double(box.size.height),
            "confidence": Double(observation.confidence)
          ]
          request.inputObservation = observation
          DispatchQueue.main.async { result(payload) }
        } else {
          DispatchQueue.main.async { result(nil) }
        }
      } catch {
        DispatchQueue.main.async { result(nil) }
      }
    }
  }

  // 高效建立 CVPixelBuffer
  private func createPixelBuffer(from data: Data, width: Int, height: Int) -> CVPixelBuffer? {
    var pixelBuffer: CVPixelBuffer?
    let options: [CFString: Any] = [
      kCVPixelBufferCGImageCompatibilityKey: true,
      kCVPixelBufferCGBitmapContextCompatibilityKey: true
    ]
    let status = data.withUnsafeBytes { rawBuffer in
      CVPixelBufferCreateWithBytes(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        UnsafeMutableRawPointer(mutating: rawBuffer.baseAddress!),
        width * 4,
        nil,
        nil,
        options as CFDictionary,
        &pixelBuffer
      )
    }
    return status == kCVReturnSuccess ? pixelBuffer : nil
  }
}
