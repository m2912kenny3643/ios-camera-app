import SwiftUI

struct TopStatusBarView: View {
    @ObservedObject var settings: CameraSettings
    
    var body: some View {
        HStack(spacing: 8) {
            // 拍攝模式徽章
            Text(settings.mode.rawValue)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white)
                .cornerRadius(2)
            
            // 剩餘張數
            Text("[\(settings.remainingShots)]")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("30 06:00:00")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            
            Spacer()
            
            // 對焦操作與區域
            HStack(spacing: 4) {
                Text(settings.afOperation.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(settings.afOperation == .oneShot ? .white : .cyan)
                
                Text(settings.afArea.symbol)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.6))
            .cornerRadius(2)
            
            // 驅動模式
            Text(settings.driveMode.symbol)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.2))
                .cornerRadius(2)
            
            // 白平衡
            Text(settings.whiteBalance.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            
            // 相片風格標記 (S / P / L / M)
            Text("[\(settings.pictureStyle.symbol)]")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
            
            // 記憶卡插槽
            HStack(spacing: 2) {
                Text("1")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 3)
                    .background(Color.white)
                    .foregroundColor(.black)
                Text("2")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 3)
                    .background(Color.gray)
                    .foregroundColor(.black)
            }
            
            // 電池電量
            HStack(spacing: 2) {
                Image(systemName: "battery.75")
                    .font(.system(size: 11))
                    .foregroundColor(settings.batteryPercentage > 20 ? .green : .red)
                Text("\(settings.batteryPercentage)%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.75))
    }
}
