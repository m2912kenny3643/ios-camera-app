import SwiftUI

struct QMenuView: View {
    @ObservedObject var settings: CameraSettings
    let onDismiss: () -> Void
    
    @State private var selectedCategory: QCategory = .afOperation
    
    enum QCategory: String, CaseIterable, Identifiable {
        case afOperation = "AF 操作"
        case afArea = "AF 區域"
        case driveMode = "驅動模式"
        case metering = "測光模式"
        case whiteBalance = "白平衡"
        case pictureStyle = "相片風格"
        case shootingMode = "拍攝模式"
        case level = "電子水平儀"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        ZStack {
            // 半透明暗色背景
            Color.black.opacity(0.85)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 0) {
                // 頂部標題列 (Canon 紅色重音)
                HStack {
                    Text("速控畫面 (Quick Control)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                
                // 矩陣網格主體 (4x2 網格)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    QGridButton(
                        title: "AF 操作",
                        value: settings.afOperation.rawValue,
                        isSelected: selectedCategory == .afOperation
                    ) {
                        selectedCategory = .afOperation
                    }
                    
                    QGridButton(
                        title: "AF 區域",
                        value: settings.afArea.rawValue,
                        isSelected: selectedCategory == .afArea
                    ) {
                        selectedCategory = .afArea
                    }
                    
                    QGridButton(
                        title: "驅動模式",
                        value: settings.driveMode.rawValue,
                        isSelected: selectedCategory == .driveMode
                    ) {
                        selectedCategory = .driveMode
                    }
                    
                    QGridButton(
                        title: "測光模式",
                        value: settings.meteringMode.rawValue,
                        isSelected: selectedCategory == .metering
                    ) {
                        selectedCategory = .metering
                    }
                    
                    QGridButton(
                        title: "白平衡",
                        value: settings.whiteBalance.rawValue,
                        isSelected: selectedCategory == .whiteBalance
                    ) {
                        selectedCategory = .whiteBalance
                    }
                    
                    QGridButton(
                        title: "相片風格",
                        value: settings.pictureStyle.rawValue,
                        isSelected: selectedCategory == .pictureStyle
                    ) {
                        selectedCategory = .pictureStyle
                    }
                    
                    QGridButton(
                        title: "拍攝模式",
                        value: settings.mode.rawValue,
                        isSelected: selectedCategory == .shootingMode
                    ) {
                        selectedCategory = .shootingMode
                    }
                    
                    QGridButton(
                        title: "水平儀",
                        value: settings.showLevel ? "開啟" : "關閉",
                        isSelected: selectedCategory == .level
                    ) {
                        selectedCategory = .level
                    }
                }
                .padding(12)
                
                Divider().background(Color.gray.opacity(0.4))
                
                // 底部具體選項水平滑桿 (Sub-options for selected category)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        switch selectedCategory {
                        case .afOperation:
                            ForEach(AFOperation.allCases) { item in
                                SubOptionButton(text: item.rawValue, isSelected: settings.afOperation == item) {
                                    settings.afOperation = item
                                    SoundManager.shared.playDialTick()
                                }
                            }
                        case .afArea:
                            ForEach(AFArea.allCases) { item in
                                SubOptionButton(text: item.rawValue, isSelected: settings.afArea == item) {
                                    settings.afArea = item
                                    SoundManager.shared.playDialTick()
                                }
                            }
                        case .driveMode:
                            ForEach(DriveMode.allCases) { item in
                                SubOptionButton(text: item.rawValue, isSelected: settings.driveMode == item) {
                                    settings.driveMode = item
                                    SoundManager.shared.playDialTick()
                                }
                            }
                        case .metering:
                            ForEach(MeteringMode.allCases) { item in
                                SubOptionButton(text: item.rawValue, isSelected: settings.meteringMode == item) {
                                    settings.meteringMode = item
                                    SoundManager.shared.playDialTick()
                                }
                            }
                        case .whiteBalance:
                            ForEach(WhiteBalance.allCases) { item in
                                SubOptionButton(text: item.rawValue, isSelected: settings.whiteBalance == item) {
                                    settings.whiteBalance = item
                                    SoundManager.shared.playDialTick()
                                }
                            }
                        case .pictureStyle:
                            ForEach(PictureStyleMode.allCases) { item in
                                SubOptionButton(text: item.rawValue, isSelected: settings.pictureStyle == item) {
                                    settings.pictureStyle = item
                                    SoundManager.shared.playDialTick()
                                }
                            }
                        case .shootingMode:
                            ForEach(ShootingMode.allCases) { item in
                                SubOptionButton(text: item.rawValue, isSelected: settings.mode == item) {
                                    settings.mode = item
                                    SoundManager.shared.playDialTick()
                                }
                            }
                        case .level:
                            SubOptionButton(text: "開啟", isSelected: settings.showLevel) {
                                settings.showLevel = true
                                SoundManager.shared.playDialTick()
                            }
                            SubOptionButton(text: "關閉", isSelected: !settings.showLevel) {
                                settings.showLevel = false
                                SoundManager.shared.playDialTick()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            }
            .frame(maxWidth: 580)
            .background(Color(red: 0.15, green: 0.15, blue: 0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .padding(16)
        }
    }
}

struct QGridButton: View {
    let title: String
    let value: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(isSelected ? .yellow : .white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.08))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.yellow : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SubOptionButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.yellow : Color.white.opacity(0.15))
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
