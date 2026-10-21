import SwiftUI

struct ViewfinderOverlay: View {
    @ObservedObject var settings: CameraSettings
    @ObservedObject var motionManager: MotionManager
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack {
                // 1. 三分構圖九宮格 (3x3 Grid)
                Path { path in
                    let colWidth = width / 3.0
                    let rowHeight = height / 3.0
                    
                    path.move(to: CGPoint(x: colWidth, y: 0))
                    path.addLine(to: CGPoint(x: colWidth, y: height))
                    path.move(to: CGPoint(x: colWidth * 2, y: 0))
                    path.addLine(to: CGPoint(x: colWidth * 2, y: height))
                    
                    path.move(to: CGPoint(x: 0, y: rowHeight))
                    path.addLine(to: CGPoint(x: width, y: rowHeight))
                    path.move(to: CGPoint(x: 0, y: rowHeight * 2))
                    path.addLine(to: CGPoint(x: width, y: rowHeight * 2))
                }
                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                
                // 2. Canon 經典電子水平儀 (Electronic Level)
                if settings.showLevel {
                    ZStack {
                        // 基準水平刻度 (固定於螢幕中央)
                        HStack(spacing: 30) {
                            Rectangle()
                                .fill(motionManager.isLevel ? Color.green : Color.white.opacity(0.7))
                                .frame(width: 40, height: 2)
                            
                            Circle()
                                .stroke(motionManager.isLevel ? Color.green : Color.white.opacity(0.7), lineWidth: 1.5)
                                .frame(width: 8, height: 8)
                            
                            Rectangle()
                                .fill(motionManager.isLevel ? Color.green : Color.white.opacity(0.7))
                                .frame(width: 40, height: 2)
                        }
                        .rotationEffect(.degrees(-motionManager.roll))
                        .animation(.linear(duration: 0.05), value: motionManager.roll)
                    }
                    .position(x: width / 2, y: height / 2)
                }
                
                // 3. Canon 經典對焦框 (AF Point Box)
                let afX = settings.afPointNormalized.x * width
                let afY = settings.afPointNormalized.y * height
                
                ZStack {
                    if settings.isAFLocked {
                        // 合焦鎖定狀態：亮綠色雙層對焦框
                        Rectangle()
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: 54, height: 54)
                        Rectangle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            .frame(width: 58, height: 58)
                    } else if settings.afOperation == .servo {
                        // 伺服追蹤狀態：亮藍色對焦框
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 54, height: 54)
                    } else {
                        // 待機/手動對焦狀態：白色對焦框
                        Rectangle()
                            .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                            .frame(width: 50, height: 50)
                        
                        // 中心點十字標記
                        Path { path in
                            path.move(to: CGPoint(x: 22, y: 25))
                            path.addLine(to: CGPoint(x: 28, y: 25))
                            path.move(to: CGPoint(x: 25, y: 22))
                            path.addLine(to: CGPoint(x: 25, y: 28))
                        }
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                        .frame(width: 50, height: 50)
                    }
                }
                .position(x: afX, y: afY)
                .animation(.easeOut(duration: 0.15), value: settings.isAFLocked)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: settings.afPointNormalized)
            }
        }
    }
}
