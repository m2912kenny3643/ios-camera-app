import SwiftUI

struct BottomExposureBarView: View {
    @ObservedObject var settings: CameraSettings
    let onShutterTap: () -> Void
    let onApertureTap: () -> Void
    let onISOTap: () -> Void
    let onEVTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 快門速度 (Tv)
            Button(action: onShutterTap) {
                Text(settings.currentShutter)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 光圈值 (Av)
            Button(action: onApertureTap) {
                Text(settings.currentAperture)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 曝光補償標尺 (-3 .. 0 .. +3)
            Button(action: onEVTap) {
                VStack(spacing: 2) {
                    // 刻度點與數值
                    HStack(spacing: 3) {
                        Text("-3")
                        Text("•")
                        Text("•")
                        Text("-2")
                        Text("•")
                        Text("•")
                        Text("-1")
                        Text("•")
                        Text("•")
                        Text("0")
                            .foregroundColor(.yellow)
                        Text("•")
                        Text("•")
                        Text("+1")
                        Text("•")
                        Text("•")
                        Text("+2")
                        Text("•")
                        Text("•")
                        Text("+3")
                    }
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    
                    // 游標指示器
                    GeometryReader { geo in
                        let width = geo.size.width
                        // 正規化 -3.0 ~ +3.0 到 0 ~ 1
                        let ratio = CGFloat((settings.exposureCompensation + 3.0) / 6.0)
                        let clampedX = max(0, min(width, width * ratio))
                        
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: 3, height: 6)
                            .offset(x: clampedX - 1.5)
                    }
                    .frame(height: 6)
                }
                .frame(width: 130)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.5))
                .cornerRadius(3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // ISO 感光度
            Button(action: onISOTap) {
                HStack(spacing: 2) {
                    Text("ISO")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Text(settings.currentISO)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.15))
                .cornerRadius(3)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 高光色調優先 D+ 標誌
            if settings.highlightTonePriority {
                Text("D+")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(2)
            }
            
            Spacer()
            
            // 當前轉盤指派狀態
            HStack(spacing: 3) {
                Image(systemName: "dial.low.fill")
                    .font(.system(size: 10))
                Text(settings.dialAssignment.shortName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                if settings.dialAssignment == .zoom {
                    Text(String(format: "%.1fx", settings.zoomFactor))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                } else if settings.dialAssignment == .exposureCompensation {
                    Text(String(format: "%+.1f", settings.exposureCompensation))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }
            .foregroundColor(.yellow)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.85))
    }
}
