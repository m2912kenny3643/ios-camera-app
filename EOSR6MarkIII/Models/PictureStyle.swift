import Foundation
import SwiftUI
import CoreImage

enum PictureStyleMode: String, CaseIterable, Identifiable {
    case standard = "標準"
    case portrait = "人像"
    case landscape = "風景"
    case monochrome = "單色"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .standard: return "S"
        case .portrait: return "P"
        case .landscape: return "L"
        case .monochrome: return "M"
        }
    }
    
    // Canon 預設參數 (銳利度, 對比度, 飽和度, 色調)
    var defaultParameters: (sharpness: Double, contrast: Double, saturation: Double, tone: Double) {
        switch self {
        case .standard:
            return (4.0, 0.0, 0.0, 0.0)
        case .portrait:
            return (3.0, 0.0, 0.0, -1.0) // 偏紅柔膚
        case .landscape:
            return (5.0, 1.0, 2.0, 0.0)  // 鮮明對比與藍綠增強
        case .monochrome:
            return (4.0, 1.0, -1.0, 0.0) // 純淨黑白
        }
    }
    
    // CoreImage 影像濾鏡處理
    func apply(to inputImage: CIImage) -> CIImage {
        let params = defaultParameters
        var output = inputImage
        
        switch self {
        case .monochrome:
            if let monoFilter = CIFilter(name: "CIPhotoEffectNoir") {
                monoFilter.setValue(output, forKey: kCIInputImageKey)
                if let result = monoFilter.outputImage {
                    output = result
                }
            }
        case .portrait:
            // 輕微暖化與柔化對比
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(output, forKey: kCIInputImageKey)
                colorControls.setValue(1.05, forKey: kCIInputSaturationKey)
                colorControls.setValue(0.98, forKey: kCIInputContrastKey)
                if let result = colorControls.outputImage {
                    output = result
                }
            }
        case .landscape:
            // 強化色彩鮮豔度與層次
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(output, forKey: kCIInputImageKey)
                colorControls.setValue(1.25, forKey: kCIInputSaturationKey)
                colorControls.setValue(1.10, forKey: kCIInputContrastKey)
                if let result = colorControls.outputImage {
                    output = result
                }
            }
        case .standard:
            // Canon 標準直出感：適度對比
            if let colorControls = CIFilter(name: "CIColorControls") {
                colorControls.setValue(output, forKey: kCIInputImageKey)
                colorControls.setValue(1.10, forKey: kCIInputSaturationKey)
                colorControls.setValue(1.05, forKey: kCIInputContrastKey)
                if let result = colorControls.outputImage {
                    output = result
                }
            }
        }
        
        // 銳利度補償 (Unsharp Mask)
        if params.sharpness > 0, let sharpFilter = CIFilter(name: "CIUnsharpMask") {
            sharpFilter.setValue(output, forKey: kCIInputImageKey)
            sharpFilter.setValue(params.sharpness * 0.4, forKey: kCIInputIntensityKey)
            sharpFilter.setValue(2.0, forKey: kCIInputRadiusKey)
            if let result = sharpFilter.outputImage {
                output = result
            }
        }
        
        return output
    }
}
