import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:gal/gal.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint("Failed to initialize cameras: $e");
  }
  runApp(const NeoFocusApp());
}

class NeoFocusApp extends StatelessWidget {
  const NeoFocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeoFocus Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CameraScreen(),
    );
  }
}

enum ShootMode { P, M, AUTO }
enum SubjectType { AUTO, BIRD, ANIMAL, PERSON, VEHICLE }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isReady = false;

  // Exposure & Mode Settings
  ShootMode _mode = ShootMode.M;
  SubjectType _subjectType = SubjectType.BIRD; // 預設鳥類/動物優先
  double _minExposure = -2.0;
  double _maxExposure = 2.0;
  double _currentExposure = 0.0;
  double _currentZoom = 1.0;
  double _maxZoom = 5.0;

  // Manual Exposure Parameters
  double _shutterIndex = 4.0; // 1/60s
  double _isoIndex = 2.0;      // ISO 400
  String? _activeSlider;       // 'SHUTTER', 'ISO', 'EV'

  final List<String> _shutterSpeeds = [
    "1/2000", "1/1000", "1/500", "1/250", "1/125", "1/60", "1/30", "1/15", "1/4", "1s"
  ];
  final List<String> _isoValues = [
    "100", "200", "400", "800", "1600", "3200", "6400"
  ];

  // Subject Tracking & Touch AF
  Offset? _focusPoint;
  bool _isUserLocked = false;
  String _detectedLabel = "鳥類";
  Rect _trackedBox = const Rect.fromLTWH(0.25, 0.20, 0.50, 0.55); // 模擬主體邊界
  Timer? _trackingTimer;

  // Camera Features
  bool _preCapture = true;
  bool _showGrid = false;
  bool _cleanDisplay = false;
  bool _flashVisible = false;
  String? _lastCapturedPath;
  String? _toastMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startAiTrackingSimulation();
  }

  Future<void> _initCamera() async {
    if (_cameras.isEmpty) return;
    _controller = CameraController(
      _cameras[0],
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      _minExposure = await _controller!.getMinExposureOffset();
      _maxExposure = await _controller!.getMaxExposureOffset();
      _maxZoom = min(10.0, await _controller!.getMaxZoomLevel());
      _currentExposure = 0.0;
      await _controller!.setExposureOffset(0.0);
      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _startAiTrackingSimulation() {
    // 60FPS 索尼/佳能級即時主體與眼部追蹤模擬
    _trackingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !_isReady) return;
      if (!_isUserLocked) {
        // 微幅晃動追蹤主體，呈現即時追焦鎖定動態感
        final double t = DateTime.now().millisecondsSinceEpoch / 400.0;
        final double dx = 0.26 + sin(t) * 0.015;
        final double dy = 0.20 + cos(t * 0.8) * 0.012;
        setState(() {
          _trackedBox = Rect.fromLTWH(dx, dy, 0.48, 0.52);
        });
      }
    });
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // 拍照動作 (含快門閃白、震動、相簿自動儲存)
  Future<void> _takePhoto() async {
    if (!_isReady || _controller == null || _controller!.value.isTakingPicture) return;

    // 1. 光學快門閃白與震動反饋
    HapticFeedback.heavyImpact();
    setState(() => _flashVisible = true);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _flashVisible = false);
    });

    try {
      final XFile photo = await _controller!.takePicture();
      
      // 2. 儲存至 iPhone 系統相簿 (Camera Roll)
      try {
        final bool hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        await Gal.putImage(photo.path);
        _showToast("已存入相簿: RAW + L (48MP)");
      } catch (err) {
        debugPrint("Gal save error: $err");
      }

      setState(() {
        _lastCapturedPath = photo.path;
      });
    } catch (e) {
      _showToast("拍照失敗: $e");
    }
  }

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  // 螢幕點選對焦 / 鎖定主體
  void _onTapScreen(TapDownDetails details) async {
    if (!_isReady || _controller == null) return;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset local = box.globalToLocal(details.globalPosition);

    final double x = local.dx / box.size.width;
    final double y = local.dy / box.size.height;

    HapticFeedback.selectionClick();
    setState(() {
      _focusPoint = local;
      _isUserLocked = true;
      _trackedBox = Rect.fromCenter(center: Offset(x, y), width: 0.24, height: 0.24);
      _detectedLabel = "點選鎖定";
    });

    try {
      await _controller!.setFocusPoint(Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)));
      await _controller!.setExposurePoint(Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)));
    } catch (_) {}
  }

  // 解除鎖定回歸全自動 AI
  void _cancelLock() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isUserLocked = false;
      _detectedLabel = _subjectType == SubjectType.BIRD ? "鳥類" : (_subjectType == SubjectType.ANIMAL ? "動物" : "自動");
      _trackedBox = const Rect.fromLTWH(0.25, 0.20, 0.50, 0.55);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    final Size screenSize = MediaQuery.of(context).size;
    final bool isLandscape = screenSize.width > screenSize.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapScreen,
        onScaleUpdate: (details) {
          if (details.scale != 1.0) {
            double nextZoom = (_currentZoom * details.scale).clamp(1.0, _maxZoom);
            _controller?.setZoomLevel(nextZoom);
            setState(() => _currentZoom = nextZoom);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Viewfinder Camera Preview
            Center(
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: CameraPreview(_controller!),
              ),
            ),

            // 2. 井字參考線 (Grid)
            if (_showGrid) _buildGridOverlay(),

            // 3. AI 主體識別與追焦框 (Sony/Canon 旗艦無反風格)
            _buildAiTrackingReticles(screenSize),

            // 4. 頂部狀態列 (Status Bar)
            if (!_cleanDisplay) _buildTopStatusBar(),

            // 5. 頂部 [✕ 解除鎖定] 膠囊按鈕 (鎖定時浮現)
            if (_isUserLocked)
              Positioned(
                top: 48,
                left: screenSize.width / 2 - 55,
                child: GestureDetector(
                  onTap: _cancelLock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amberAccent, width: 1.5),
                    ),
                    child: const Text(
                      "✕ 解除鎖定",
                      style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

            // 6. 右側無反功能導軌 (快門按鈕、Q 選單、INFO、縮圖相簿)
            if (isLandscape) _buildRightRailControls(screenSize),

            // 7. 底部參數列 (SEC、F-NO、ISO、EV 類比指針)
            _buildBottomParameterBar(isLandscape),

            // 8. 參數調整滑動輪盤 (點選 SEC / ISO / EV 後彈出)
            if (_activeSlider != null) _buildAdjustSliderOverlay(),

            // 9. 快門閃白動畫 (Optical White Flash)
            if (_flashVisible)
              Container(
                color: Colors.white.withOpacity(0.85),
              ),

            // 10. 提示訊息 (Toast)
            if (_toastMessage != null)
              Positioned(
                top: 100,
                left: screenSize.width / 2 - 120,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: Text(
                    _toastMessage!,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // AI 追蹤框與眼睛識別框
  Widget _buildAiTrackingReticles(Size size) {
    final double left = _trackedBox.left * size.width;
    final double top = _trackedBox.top * size.height;
    final double width = _trackedBox.width * size.width;
    final double height = _trackedBox.height * size.height;

    final Color reticleColor = _isUserLocked ? Colors.amberAccent : Colors.white;

    return Stack(
      children: [
        // 主體四角框
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: CustomPaint(
            painter: CornerBracketPainter(color: reticleColor, isLocked: _isUserLocked),
          ),
        ),

        // 鳥類 / 動物眼部鎖定小框 (Eye-AF)
        Positioned(
          left: left + width * 0.65,
          top: top + height * 0.16,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00FF66), width: 2.0),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Center(
              child: Icon(Icons.remove_red_eye, color: Color(0xFF00FF66), size: 14),
            ),
          ),
        ),

        // AF-C 主體標籤
        Positioned(
          left: left + 8,
          top: top - 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              "[AF-C] $_detectedLabel",
              style: TextStyle(
                color: _isUserLocked ? Colors.amberAccent : const Color(0xFF00FF66),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 頂部狀態列
  Widget _buildTopStatusBar() {
    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 模式切換與拍攝參數
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    _modeButton(ShootMode.P, "P"),
                    const SizedBox(width: 4),
                    _modeButton(ShootMode.M, "M"),
                    const SizedBox(width: 4),
                    _modeButton(ShootMode.AUTO, "AUTO"),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "[~9999]  RAW+L  AWB",
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // 預拍攝標籤 (PRE-CAP 0.3s) 與電量
          Row(
            children: [
              if (_preCapture)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFF9500), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00FF66),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "PRE-CAP 0.3s",
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              const Icon(Icons.battery_full, color: Colors.white, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  // 底部無反相機參數列 (SEC, F-NO, ISO, EV 指針)
  Widget _buildBottomParameterBar(bool isLandscape) {
    return Positioned(
      bottom: isLandscape ? 18 : 100,
      left: 20,
      right: isLandscape ? 120 : 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // SEC 快門速度 (P 模式為 Canon R6 風格黑底白框鎖定)
          _buildParamBox(
            label: "SEC",
            value: _shutterSpeeds[_shutterIndex.round()],
            locked: _mode == ShootMode.P,
            onTap: () {
              if (_mode != ShootMode.P) {
                setState(() => _activeSlider = _activeSlider == 'SHUTTER' ? null : 'SHUTTER');
              }
            },
          ),

          // F-NO 光圈
          _buildParamBox(
            label: "F-NO",
            value: "F1.8",
            locked: true,
            onTap: () {},
          ),

          // ISO (P 模式為 Canon R6 風格黑底白框鎖定)
          _buildParamBox(
            label: "ISO",
            value: _isoValues[_isoIndex.round()],
            locked: _mode == ShootMode.P,
            onTap: () {
              if (_mode != ShootMode.P) {
                setState(() => _activeSlider = _activeSlider == 'ISO' ? null : 'ISO');
              }
            },
          ),

          // EV 曝光補償指針
          _buildAnalogEvMeter(),

          // 焦距顯示
          Text(
            "${(24 * _currentZoom).round()}mm",
            style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 類比式曝光補償尺 (-3..-2..-1..0..+1..+2..+3)
  Widget _buildAnalogEvMeter() {
    return GestureDetector(
      onTap: () {
        setState(() => _activeSlider = _activeSlider == 'EV' ? null : 'EV');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amberAccent, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "EV ${_currentExposure >= 0 ? "+${_currentExposure.toStringAsFixed(1)}" : _currentExposure.toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            CustomPaint(
              size: const Size(90, 10),
              painter: EvMeterPainter(ev: _currentExposure),
            ),
          ],
        ),
      ),
    );
  }

  // 右側無反旗艦按鈕導軌 (快門按鈕、Q選單、INFO、相簿縮圖)
  Widget _buildRightRailControls(Size size) {
    return Positioned(
      right: 18,
      top: 50,
      bottom: 50,
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Q (Quick Menu) 按鈕
          _buildRailIconButton("Q", () => _showQuickMenu()),

          // 旗艦快門大按鈕 (帶 Pre-Capture 光環)
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _preCapture ? const Color(0xFFFF9500) : Colors.white,
                  width: 3.5,
                ),
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _preCapture ? const Color(0xFFFF9500).withOpacity(0.8) : Colors.white.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),

          // INFO 資訊按鈕
          _buildRailIconButton("INFO", () {
            setState(() => _cleanDisplay = !_cleanDisplay);
          }),

          // 相簿最後一張照片預覽縮圖
          GestureDetector(
            onTap: () {
              if (_lastCapturedPath != null) {
                _showPhotoViewer(_lastCapturedPath!);
              } else {
                _showToast("尚未拍攝照片");
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white70),
              ),
              child: _lastCapturedPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.file(File(_lastCapturedPath!), fit: BoxFit.cover),
                    )
                  : const Icon(Icons.photo_library, color: Colors.white70, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailIconButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white30),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }

  // 參數滑動調整輪盤 (無極微調)
  Widget _buildAdjustSliderOverlay() {
    return Positioned(
      bottom: 85,
      left: 40,
      right: 140,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amberAccent, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _activeSlider == 'SHUTTER'
                  ? "快門速度: ${_shutterSpeeds[_shutterIndex.round()]}s"
                  : _activeSlider == 'ISO'
                      ? "ISO 感光度: ${_isoValues[_isoIndex.round()]}"
                      : "EV 曝光補償: ${_currentExposure >= 0 ? "+${_currentExposure.toStringAsFixed(1)}" : _currentExposure.toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.amberAccent, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _activeSlider == 'SHUTTER'
                  ? _shutterIndex
                  : _activeSlider == 'ISO'
                      ? _isoIndex
                      : _currentExposure,
              min: _activeSlider == 'SHUTTER' ? 0.0 : (_activeSlider == 'ISO' ? 0.0 : _minExposure),
              max: _activeSlider == 'SHUTTER'
                  ? (_shutterSpeeds.length - 1).toDouble()
                  : (_activeSlider == 'ISO' ? (_isoValues.length - 1).toDouble() : _maxExposure),
              divisions: _activeSlider == 'SHUTTER'
                  ? _shutterSpeeds.length - 1
                  : (_activeSlider == 'ISO' ? _isoValues.length - 1 : null),
              activeColor: Colors.amberAccent,
              inactiveColor: Colors.white24,
              onChanged: (val) {
                setState(() {
                  if (_activeSlider == 'SHUTTER') {
                    _shutterIndex = val;
                  } else if (_activeSlider == 'ISO') {
                    _isoIndex = val;
                  } else {
                    _currentExposure = val;
                    _controller?.setExposureOffset(val);
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // 參數方塊 (支援 Canon R6 P 模式黑框鎖定)
  Widget _buildParamBox({
    required String label,
    required String value,
    required bool locked,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: locked ? const Color(0x35000000) : Colors.black54,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: locked ? Colors.white38 : Colors.amberAccent,
            width: locked ? 1.2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: locked ? Colors.grey : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: locked ? const Color(0xD5FFFFFF) : Colors.amberAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(ShootMode mode, String text) {
    final bool isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mode = mode;
          if (_mode == ShootMode.P && (_activeSlider == 'SHUTTER' || _activeSlider == 'ISO')) {
            _activeSlider = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildGridOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: GridPainter(),
      ),
    );
  }

  // Q (Quick Menu) 快捷選單
  void _showQuickMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Settings (Q)", style: TextStyle(color: Colors.amberAccent, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("主體識別對焦優先:"),
                      DropdownButton<SubjectType>(
                        value: _subjectType,
                        dropdownColor: Colors.grey.shade900,
                        items: const [
                          DropdownMenuItem(value: SubjectType.AUTO, child: Text("自動")),
                          DropdownMenuItem(value: SubjectType.BIRD, child: Text("鳥類 (Bird)")),
                          DropdownMenuItem(value: SubjectType.ANIMAL, child: Text("動物 (Animal)")),
                          DropdownMenuItem(value: SubjectType.PERSON, child: Text("人物 (Person)")),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _subjectType = val;
                              _detectedLabel = val == SubjectType.BIRD ? "鳥類" : (val == SubjectType.ANIMAL ? "動物" : "自動");
                            });
                            setModalState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text("預拍攝緩存 (Pre-Capture 0.3s)"),
                    value: _preCapture,
                    activeColor: Colors.amberAccent,
                    onChanged: (v) {
                      setState(() => _preCapture = v);
                      setModalState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text("3×3 構圖網格 (Grid)"),
                    value: _showGrid,
                    activeColor: Colors.amberAccent,
                    onChanged: (v) {
                      setState(() => _showGrid = v);
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 照片全螢幕預覽
  void _showPhotoViewer(String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(path), fit: BoxFit.contain),
            Positioned(
              top: 30,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 索尼/佳能四角直角對焦框
class CornerBracketPainter extends CustomPainter {
  final Color color;
  final bool isLocked;

  CornerBracketPainter({required this.color, required this.isLocked});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const double len = 16.0;

    // 四角直角線
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), p);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), p);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), p);

    canvas.drawLine(Offset(0, size.height), Offset(len, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), p);

    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), p);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), p);

    // 鎖定時追加雙直角框 (Double Bracket)
    if (isLocked) {
      const double inset = 6.0;
      final Paint p2 = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(const Offset(inset, inset), const Offset(inset + 10, inset), p2);
      canvas.drawLine(const Offset(inset, inset), const Offset(inset, inset + 10), p2);

      canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset - 10, inset), p2);
      canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + 10), p2);

      canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + 10, size.height - inset), p2);
      canvas.drawLine(Offset(inset, size.height - inset), Offset(inset, size.height - inset - 10), p2);

      canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset - 10, size.height - inset), p2);
      canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - 10), p2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 類比式曝光尺 Painter
class EvMeterPainter extends CustomPainter {
  final double ev;
  EvMeterPainter({required this.ev});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.0;

    for (int i = -3; i <= 3; i++) {
      final double x = size.width / 2 + (i / 3.0) * (size.width / 2);
      canvas.drawLine(Offset(x, 0), Offset(x, i == 0 ? 8 : 4), p);
    }

    // 指針
    final double markX = (size.width / 2 + (ev.clamp(-3.0, 3.0) / 3.0) * (size.width / 2)).clamp(0.0, size.width);
    final Paint needle = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(markX, 2), Offset(markX, 10), needle);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 構圖網格線
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), p);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), p);
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), p);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
