import SwiftUI

struct PhysicalControlsPanel: View {
    @ObservedObject var settings: CameraSettings
    let cameraService: CameraService
    
    @State private var isHalfPressed = false
    @State private var dialDragOffset: CGFloat = 0.0
    
    var body: some View {
        HStack(spacing: 0) {
            // 左側相機控制欄 (Left Body Grip Panel)
            VStack(spacing: 16) {
                // 回放按鈕 [ ▶ ]
                BodyRoundButton(label: "▶", subtitle: "PLAY") {
                    settings.showPlayback = true
                    SoundManager.shared.playButtonFeedback()
                }
                
                // 垃圾桶按鈕 [ 🗑️ ]
                BodyRoundButton(label: "🗑", subtitle: "ERASE") {
                    SoundManager.shared.playButtonFeedback()
                }
                
                Spacer()
                
                // 拍攝模式快速切換輪 (Mode Dial Indicator)
                VStack(spacing: 4) {
                    Text("MODE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        let all = ShootingMode.allCases
                        if let idx = all.firstIndex(of: settings.mode) {
                            settings.mode = all[(idx + 1) % all.count]
                            SoundManager.shared.playDialTick()
                        }
                    }) {
                        Text(settings.mode.rawValue)
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(white: 0.2)))
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .frame(width: 56)
            .padding(.vertical, 16)
            .background(Color(white: 0.07))
            
            Spacer()
            
            // 右側相機主控面板 (Right Body Grip Panel)
            VStack(spacing: 12) {
                // AF-ON 按鈕 (按住鎖定對焦)
                Button(action: {}) {
                    VStack(spacing: 2) {
                        Text("AF-ON")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 48, height: 32)
                    .background(Color(white: 0.18))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHalfPressed {
                                isHalfPressed = true
                                cameraService.lockFocusAndExposure()
                                SoundManager.shared.playButtonFeedback()
                            }
                        }
                        .onEnded { _ in
                            isHalfPressed = false
                            cameraService.unlockFocusAndExposure()
                        }
                )
                
                // M-Fn 多功能切換鍵
                BodySquareButton(title: "M-Fn", subtitle: settings.dialAssignment.shortName) {
                    settings.cycleDialAssignment()
                    SoundManager.shared.playButtonFeedback()
                }
                
                // Q 速控按鈕
                BodySquareButton(title: "Q", subtitle: "MENU", isHighlighted: settings.showQMenu) {
                    settings.showQMenu.toggle()
                    SoundManager.shared.playButtonFeedback()
                }
                
                // COLOR 色彩模式按鈕
                BodySquareButton(title: "COLOR", subtitle: settings.pictureStyle.symbol) {
                    let allStyles = PictureStyleMode.allCases
                    if let idx = allStyles.firstIndex(of: settings.pictureStyle) {
                        settings.pictureStyle = allStyles[(idx + 1) % allStyles.count]
                        SoundManager.shared.playButtonFeedback()
                    }
                }
                
                Spacer()
                
                // 擬真速控轉盤 (Rotary Dial Simulator)
                VStack(spacing: 2) {
                    Text("DIAL")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.gray)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(white: 0.15))
                            .frame(width: 44, height: 60)
                            .overlay(
                                VStack(spacing: 5) {
                                    ForEach(0..<6) { _ in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(width: 32, height: 2)
                                    }
                                }
                            )
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let delta = (value.translation.height - dialDragOffset) * -0.1
                                dialDragOffset = value.translation.height
                                CameraControlManager.shared.handleDialValueChange(delta: delta)
                            }
                            .onEnded { _ in
                                dialDragOffset = 0
                            }
                    )
                }
                
                // 螢幕雙段實體模擬快門鈕 (Two-Stage Shutter)
                ZStack {
                    Circle()
                        .fill(Color(white: 0.2))
                        .frame(width: 52, height: 52)
                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                    
                    Circle()
                        .fill(isHalfPressed ? Color.green.opacity(0.8) : Color.white)
                        .frame(width: 42, height: 42)
                        .scaleEffect(isHalfPressed ? 0.92 : 1.0)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isHalfPressed {
                                isHalfPressed = true
                                cameraService.lockFocusAndExposure()
                            }
                        }
                        .onEnded { _ in
                            cameraService.capturePhoto()
                            isHalfPressed = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                cameraService.unlockFocusAndExposure()
                            }
                        }
                )
            }
            .frame(width: 64)
            .padding(.vertical, 14)
            .background(Color(white: 0.07))
        }
    }
}

struct BodyRoundButton: View {
    let label: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray)
            }
            .frame(width: 38, height: 38)
            .background(Circle().fill(Color(white: 0.16)))
            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BodySquareButton: View {
    let title: String
    let subtitle: String
    var isHighlighted: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isHighlighted ? .black : .white)
                Text(subtitle)
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundColor(isHighlighted ? .black : .yellow)
            }
            .frame(width: 46, height: 30)
            .background(isHighlighted ? Color.yellow : Color(white: 0.16))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
