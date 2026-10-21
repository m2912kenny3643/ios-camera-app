import Foundation
import SwiftUI
import Combine

// MARK: - 拍攝模式 (Shooting Mode)
enum ShootingMode: String, CaseIterable, Identifiable {
    case program = "P"
    case shutterPriority = "Tv"
    case aperturePriority = "Av"
    case manual = "M"
    case flexiblePriority = "Fv"
    case auto = "A+"
    case bulb = "B"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .program: return "P 程式自動"
        case .shutterPriority: return "Tv 快門先決"
        case .aperturePriority: return "Av 光圈先決"
        case .manual: return "M 手動曝光"
        case .flexiblePriority: return "Fv 靈活先決"
        case .auto: return "A+ 智慧場景"
        case .bulb: return "B 快門曝光"
        }
    }
}

// MARK: - 驅動模式 (Drive Mode)
enum DriveMode: String, CaseIterable, Identifiable {
    case single = "單張"
    case highPlus = "高速連拍+"
    case high = "高速連拍"
    case low = "低速連拍"
    case timer10s = "自拍 10秒"
    case timer2s = "自拍 2秒"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .single: return "rectangle"
        case .highPlus: return "square.stack.3d.forward.dottedline.fill"
        case .high: return "square.stack.3d.down.right.fill"
        case .low: return "square.stack"
        case .timer10s: return "timer"
        case .timer2s: return "timer"
        }
    }
    
    var symbol: String {
        switch self {
        case .single: return "□"
        case .highPlus: return "H+"
        case .high: return "H"
        case .low: return "L"
        case .timer10s: return "10s"
        case .timer2s: return "2s"
        }
    }
}

// MARK: - 自動對焦操作 (AF Operation)
enum AFOperation: String, CaseIterable, Identifiable {
    case oneShot = "ONE SHOT"
    case servo = "SERVO"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .oneShot: return "單次自動對焦 (One-Shot)"
        case .servo: return "伺服自動對焦 (Servo)"
        }
    }
}

// MARK: - 自動對焦區域 (AF Area)
enum AFArea: String, CaseIterable, Identifiable {
    case spot = "重點"
    case singlePoint = "單點"
    case expand = "擴展"
    case zone = "彈性區域"
    case whole = "全區域"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .spot: return "[-]"
        case .singlePoint: return "[+]"
        case .expand: return "[::]"
        case .zone: return "[ 1 ]"
        case .whole: return "[   ]"
        }
    }
}

// MARK: - 白平衡 (White Balance)
enum WhiteBalance: String, CaseIterable, Identifiable {
    case awb = "AWB"
    case awbWhite = "AWB-W"
    case daylight = "日光"
    case shade = "陰影"
    case cloudy = "陰天"
    case tungsten = "鎢絲燈"
    case fluorescent = "白光管"
    
    var id: String { rawValue }
    
    var colorTemperature: Int {
        switch self {
        case .awb, .awbWhite: return 5200
        case .daylight: return 5200
        case .shade: return 7000
        case .cloudy: return 6000
        case .tungsten: return 3200
        case .fluorescent: return 4000
        }
    }
}

// MARK: - 測光模式 (Metering Mode)
enum MeteringMode: String, CaseIterable, Identifiable {
    case evaluative = "權衡式"
    case partial = "局部"
    case spot = "重點"
    case centerWeighted = "中央偏重"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .evaluative: return "(⚪)"
        case .partial: return "( ◯ )"
        case .spot: return "( • )"
        case .centerWeighted: return "[⚪]"
        }
    }
}

// MARK: - 相機按鍵轉盤指定控制 (Camera Control Dial Assignment)
enum DialAssignment: String, CaseIterable, Identifiable {
    case zoom = "變焦 (Zoom)"
    case exposureCompensation = "曝光補償 (EV)"
    case manualFocus = "手動對焦 (MF)"
    case pictureStyle = "相片風格 (Style)"
    
    var id: String { rawValue }
    
    var shortName: String {
        switch self {
        case .zoom: return "ZOOM"
        case .exposureCompensation: return "± EV"
        case .manualFocus: return "MF"
        case .pictureStyle: return "STYLE"
        }
    }
}

// MARK: - 全域相機設定狀態 (Observable Camera State)
class CameraSettings: ObservableObject {
    @Published var mode: ShootingMode = .manual
    @Published var driveMode: DriveMode = .single
    @Published var afOperation: AFOperation = .oneShot
    @Published var afArea: AFArea = .singlePoint
    @Published var whiteBalance: WhiteBalance = .awb
    @Published var meteringMode: MeteringMode = .evaluative
    @Published var pictureStyle: PictureStyleMode = .standard
    @Published var dialAssignment: DialAssignment = .zoom
    
    // 曝光參數
    @Published var shutterSpeedIndex: Int = 4 // 1/500
    @Published var apertureIndex: Int = 1     // F1.8
    @Published var isoIndex: Int = 0          // AUTO
    @Published var exposureCompensation: Double = 0.0 // -3.0 .. +3.0
    @Published var highlightTonePriority: Bool = true // D+
    
    // 對焦與系統狀態
    @Published var isAFLocked: Bool = false
    @Published var isAFGreen: Bool = false
    @Published var afPointNormalized: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Published var zoomFactor: CGFloat = 1.0
    @Published var manualFocusDistance: Float = 0.5
    
    // UI 顯示控制
    @Published var showQMenu: Bool = false
    @Published var showPlayback: Bool = false
    @Published var showLevel: Bool = true
    @Published var rollAngle: Double = 0.0
    @Published var pitchAngle: Double = 0.0
    @Published var remainingShots: Int = 9999
    @Published var batteryPercentage: Int = 95
    @Published var lastCapturedImage: UIImage? = nil
    
    let shutterSpeeds = [
        "1/8000", "1/4000", "1/2000", "1/1000",
        "1/500", "1/250", "1/125", "1/60",
        "1/30", "1/15", "1/8", "1/4",
        "0.5\"", "1\"", "2\"", "4\"", "B"
    ]
    
    let apertures = [
        "F1.4", "F1.8", "F2.0", "F2.8",
        "F4.0", "F5.6", "F8.0", "F11",
        "F16", "F22"
    ]
    
    let isoSpeeds = [
        "AUTO", "100", "200", "400",
        "800", "1600", "3200", "6400", "12800"
    ]
    
    var currentShutter: String { shutterSpeeds[shutterSpeedIndex] }
    var currentAperture: String { apertures[apertureIndex] }
    var currentISO: String { isoSpeeds[isoIndex] }
    
    // 循環切換轉盤控制
    func cycleDialAssignment() {
        let all = DialAssignment.allCases
        if let idx = all.firstIndex(of: dialAssignment) {
            let next = (idx + 1) % all.count
            dialAssignment = all[next]
        }
    }
}
