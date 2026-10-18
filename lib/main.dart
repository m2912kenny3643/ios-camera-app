import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint("Failed to get cameras: $e");
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

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

enum ShootMode { P, M, AUTO }

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isReady = false;

  ShootMode _mode = ShootMode.M;
  double _minExposure = -2.0;
  double _maxExposure = 2.0;
  double _currentExposure = 0.0;

  // Manual Exposure Parameters
  double _shutterIndex = 4.0; // 1/125s
  double _isoIndex = 2.0;      // ISO 400
  String? _activeSlider;       // 'SHUTTER', 'ISO', 'EV'

  final List<String> _shutterSpeeds = [
    "1/1000", "1/500", "1/250", "1/125", "1/60", "1/30", "1/15", "1/4", "1s"
  ];
  final List<String> _isoValues = [
    "100", "200", "400", "800", "1600", "3200", "6400"
  ];

  // Touch AF Box
  Offset? _focusPoint;
  bool _showFocusBox = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
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
      _currentExposure = 0.0;
      await _controller!.setExposureOffset(0.0);
      if (mounted) setState(() => _isReady = true);
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onTapScreen(TapDownDetails details) async {
    if (!_isReady || _controller == null) return;
    final RenderBox box = context.findRenderBox() as RenderBox;
    final Offset local = box.globalToLocal(details.globalPosition);

    setState(() {
      _focusPoint = local;
      _showFocusBox = true;
    });

    final double x = local.dx / box.size.width;
    final double y = local.dy / box.size.height;

    try {
      await _controller!.setFocusPoint(Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)));
      await _controller!.setExposurePoint(Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0)));
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _showFocusBox = false);
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

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapScreen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera Viewfinder
            Center(
              child: CameraPreview(_controller!),
            ),

            // 2. Touch AF Reticle
            if (_showFocusBox && _focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 36,
                top: _focusPoint!.dy - 36,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.greenAccent, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Icon(Icons.center_focus_strong, color: Colors.greenAccent, size: 20),
                  ),
                ),
              ),

            // 3. Top Status Bar (Pro Mirrorless style)
            Positioned(
              top: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        _modeButton(ShootMode.P, "P"),
                        const SizedBox(width: 6),
                        _modeButton(ShootMode.M, "M"),
                        const SizedBox(width: 6),
                        _modeButton(ShootMode.AUTO, "AUTO"),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "RAW + L | 4K 60P",
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // 4. Slider Adjustment Area (Active overlay)
            if (_activeSlider != null)
              Positioned(
                bottom: 120,
                left: 30,
                right: 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                : "EV 曝光補償: ${_currentExposure.toStringAsFixed(1)}",
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _activeSlider == 'SHUTTER'
                            ? _shutterIndex
                            : _activeSlider == 'ISO'
                                ? _isoIndex
                                : _currentExposure,
                        min: _activeSlider == 'SHUTTER'
                            ? 0.0
                            : _activeSlider == 'ISO'
                                ? 0.0
                                : _minExposure,
                        max: _activeSlider == 'SHUTTER'
                            ? (_shutterSpeeds.length - 1).toDouble()
                            : _activeSlider == 'ISO'
                                ? (_isoValues.length - 1).toDouble()
                                : _maxExposure,
                        divisions: _activeSlider == 'SHUTTER'
                            ? _shutterSpeeds.length - 1
                            : _activeSlider == 'ISO'
                                ? _isoValues.length - 1
                                : null,
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
              ),

            // 5. Bottom Mirrorless HUD & Exposure Parameters
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 快門速度 (M 模式可調，P 模式鎖定框)
                  _hudParamItem(
                    label: "SEC",
                    value: _shutterSpeeds[_shutterIndex.round()],
                    locked: _mode == ShootMode.P,
                    onTap: () {
                      if (_mode != ShootMode.P) {
                        setState(() => _activeSlider = _activeSlider == 'SHUTTER' ? null : 'SHUTTER');
                      }
                    },
                  ),
                  // 光圈
                  _hudParamItem(
                    label: "F-NO",
                    value: "F1.8",
                    locked: true,
                    onTap: () {},
                  ),
                  // ISO (M 模式可調，P 模式鎖定框)
                  _hudParamItem(
                    label: "ISO",
                    value: _isoValues[_isoIndex.round()],
                    locked: _mode == ShootMode.P,
                    onTap: () {
                      if (_mode != ShootMode.P) {
                        setState(() => _activeSlider = _activeSlider == 'ISO' ? null : 'ISO');
                      }
                    },
                  ),
                  // EV 曝光補償 (點選滑動調整)
                  _hudParamItem(
                    label: "EV",
                    value: (_currentExposure >= 0 ? "+${_currentExposure.toStringAsFixed(1)}" : _currentExposure.toStringAsFixed(1)),
                    locked: false,
                    onTap: () {
                      setState(() => _activeSlider = _activeSlider == 'EV' ? null : 'EV');
                    },
                  ),
                ],
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

  Widget _hudParamItem({
    required String label,
    required String value,
    required bool locked,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: locked ? Colors.white10 : Colors.black54,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: locked ? Colors.grey.shade700 : Colors.amberAccent,
            width: locked ? 1 : 1.5,
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
                color: locked ? Colors.grey : Colors.amberAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
