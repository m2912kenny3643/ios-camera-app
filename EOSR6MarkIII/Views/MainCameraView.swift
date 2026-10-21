import SwiftUI

struct MainCameraView: View {
    @StateObject private var settings = CameraSettings()
    @StateObject private var cameraService = CameraService()
    @StateObject private var motionManager = MotionManager()
    
    @State private var showShutterPicker = false
    @State private var showAperturePicker = false
    @State private var showISOPicker = false
    
    var body: some View {
        ZStack {
            // 背景底色：Canon 專業啞光深黑
            Color(white: 0.05).edgesIgnoringSafeArea(.all)
            
            // 相機主體佈局
            HStack(spacing: 0) {
                // 左側實體快捷功能區
                BodyLeftControlPanel(settings: settings)
                
                // 中央取景核心螢幕 (3:2 機背螢幕比例)
                VStack(spacing: 0) {
                    // 頂部狀態列
                    TopStatusBarView(settings: settings)
                    
                    // 取景預覽與對焦疊加層 (維持 3:2 經典片幅)
                    ZStack {
                        CameraPreviewView(session: cameraService.session, cameraService: cameraService, settings: settings)
                            .aspectRatio(3.0 / 2.0, contentMode: .fit)
                            .clipped()
                        
                        ViewfinderOverlay(settings: settings, motionManager: motionManager)
                            .aspectRatio(3.0 / 2.0, contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // 底部曝光控制列
                    BottomExposureBarView(
                        settings: settings,
                        onShutterTap: { showShutterPicker.toggle() },
                        onApertureTap: { showAperturePicker.toggle() },
                        onISOTap: { showISOPicker.toggle() },
                        onEVTap: {
                            settings.dialAssignment = .exposureCompensation
                            SoundManager.shared.playButtonFeedback()
                        }
                    )
                }
                .background(Color.black)
                .overlay(
                    Rectangle().stroke(Color(white: 0.2), lineWidth: 1)
                )
                
                // 右側主控與相機按鍵操作面板
                BodyRightControlPanel(settings: settings, cameraService: cameraService)
            }
            .edgesIgnoringSafeArea(.all)
            
            // 覆蓋層：速控選單 (Q Menu)
            if settings.showQMenu {
                QMenuView(settings: settings) {
                    settings.showQMenu = false
                }
                .transition(.opacity)
            }
            
            // 覆蓋層：照片回放 (Playback)
            if settings.showPlayback {
                PlaybackView(settings: settings) {
                    settings.showPlayback = false
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            cameraService.settings = settings
        }
        .sheet(isPresented: $showShutterPicker) {
            PickerSheet(title: "快門速度 (Tv)", items: settings.shutterSpeeds, selectedIdx: $settings.shutterSpeedIndex)
        }
        .sheet(isPresented: $showAperturePicker) {
            PickerSheet(title: "光圈 (Av)", items: settings.apertures, selectedIdx: $settings.apertureIndex)
        }
        .sheet(isPresented: $showISOPicker) {
            PickerSheet(title: "ISO 感光度", items: settings.isoSpeeds, selectedIdx: $settings.isoIndex)
        }
    }
}

// MARK: - 左側控制面板
struct BodyLeftControlPanel: View {
    @ObservedObject var settings: CameraSettings
    
    var body: some View {
        VStack(spacing: 16) {
            BodyRoundButton(label: "▶", subtitle: "PLAY") {
                settings.showPlayback = true
                SoundManager.shared.playButtonFeedback()
            }
            
            BodyRoundButton(label: "🗑", subtitle: "ERASE") {
                SoundManager.shared.playButtonFeedback()
            }
            
            Spacer()
            
            // 模式轉盤按鈕
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
        .frame(width: 54)
        .padding(.vertical, 16)
        .background(Color(white: 0.08))
    }
}

// MARK: - 右側控制面板
struct BodyRightControlPanel: View {
    @ObservedObject var settings: CameraSettings
    let cameraService: CameraService
    
    @State private var isHalfPressed = false
    @State private var dialDragOffset: CGFloat = 0.0
    
    var body: some View {
        VStack(spacing: 12) {
            // AF-ON
            Button(action: {}) {
                Text("AF-ON")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 30)
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
                        }
                    }
                    .onEnded { _ in
                        isHalfPressed = false
                        cameraService.unlockFocusAndExposure()
                    }
            )
            
            // M-Fn 鍵
            BodySquareButton(title: "M-Fn", subtitle: settings.dialAssignment.shortName) {
                settings.cycleDialAssignment()
                SoundManager.shared.playButtonFeedback()
            }
            
            // Q 鍵
            BodySquareButton(title: "Q", subtitle: "MENU", isHighlighted: settings.showQMenu) {
                settings.showQMenu.toggle()
                SoundManager.shared.playButtonFeedback()
            }
            
            // COLOR 鍵
            BodySquareButton(title: "COLOR", subtitle: settings.pictureStyle.symbol) {
                let allStyles = PictureStyleMode.allCases
                if let idx = allStyles.firstIndex(of: settings.pictureStyle) {
                    settings.pictureStyle = allStyles[(idx + 1) % allStyles.count]
                    SoundManager.shared.playButtonFeedback()
                }
            }
            
            Spacer()
            
            // 擬真轉盤 (對應實體相機控制鍵滑動或觸控滑動)
            VStack(spacing: 2) {
                Text("DIAL")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.gray)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(white: 0.16))
                        .frame(width: 42, height: 56)
                        .overlay(
                            VStack(spacing: 4) {
                                ForEach(0..<5) { _ in
                                    Rectangle()
                                        .fill(Color.white.opacity(0.35))
                                        .frame(width: 28, height: 2)
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
            
            // 雙段快門按鍵 (半按合焦、全按釋放)
            ZStack {
                Circle()
                    .fill(Color(white: 0.22))
                    .frame(width: 50, height: 50)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1.5))
                
                Circle()
                    .fill(isHalfPressed ? Color.green : Color.white)
                    .frame(width: 40, height: 40)
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
        .frame(width: 60)
        .padding(.vertical, 14)
        .background(Color(white: 0.08))
    }
}

// MARK: - 參數滾輪選擇 Sheet
struct PickerSheet: View {
    let title: String
    let items: [String]
    @Binding var selectedIdx: Int
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.system(size: 15, weight: .bold))
            }
            .padding()
            
            Picker(title, selection: $selectedIdx) {
                ForEach(0..<items.count, id: \.self) { idx in
                    Text(items[idx]).tag(idx)
                }
            }
            .pickerStyle(WheelPickerStyle())
            
            Spacer()
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - 機身擬真圓形按鈕
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

// MARK: - 機身擬真方形按鈕
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

