import SwiftUI

struct PlaybackView: View {
    @ObservedObject var settings: CameraSettings
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if let image = settings.lastCapturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .edgesIgnoringSafeArea(.all)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("無影像記錄 (No Images)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            // Canon 回放頂部資訊欄 (Playback Top Bar)
            VStack {
                HStack(spacing: 12) {
                    Text("1/1")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("100-0001")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(Date(), formatter: Self.dateFormatter)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    Button(action: onDismiss) {
                        Text("返回 (BACK)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.75))
                
                Spacer()
                
                // Canon 回放底部詳細 Exif 曝光資訊 (Playback Detail Bar)
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Text("P")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 4)
                            .background(Color.white)
                            .cornerRadius(2)
                        
                        Text(settings.currentShutter)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(settings.currentAperture)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text(String(format: "%+.1f", settings.exposureCompensation))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Text("ISO \(settings.currentISO)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // 模擬直方圖縮圖
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 48, height: 24)
                        .overlay(
                            Path { path in
                                path.move(to: CGPoint(x: 4, y: 20))
                                path.addQuadCurve(to: CGPoint(x: 24, y: 6), control: CGPoint(x: 14, y: 8))
                                path.addQuadCurve(to: CGPoint(x: 44, y: 22), control: CGPoint(x: 34, y: 14))
                            }
                            .stroke(Color.white, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.75))
            }
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()
}
