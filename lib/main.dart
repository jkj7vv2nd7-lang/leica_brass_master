import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const ChromaFieldMasterApp());
}

class ChromaFieldMasterApp extends StatelessWidget {
  const ChromaFieldMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChromaField Master Leica Edition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1110),
        primaryColor: const Color(0xFFE5C158),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5C158),
          secondary: Color(0xFF2A4D3B),
          surface: Color(0xFF181A19),
        ),
      ),
      home: const MainMeterScreen(),
    );
  }
}

class FilmPreset {
  final String name;
  final String brand;
  final int defaultIso;
  final double evOffset;
  final double reciprocityFactor;

  const FilmPreset({
    required this.name,
    required this.brand,
    required this.defaultIso,
    this.evOffset = 0.0,
    this.reciprocityFactor = 1.3,
  });
}

const List<FilmPreset> kFilmDatabase = [
  FilmPreset(name: "Portra 400", brand: "Kodak", defaultIso: 400, evOffset: 0.33, reciprocityFactor: 1.3),
  FilmPreset(name: "Gold 200", brand: "Kodak", defaultIso: 200, evOffset: 0.0, reciprocityFactor: 1.4),
  FilmPreset(name: "Tri-X 400", brand: "Kodak", defaultIso: 400, evOffset: 0.0, reciprocityFactor: 1.5),
  FilmPreset(name: "CineStill 800T", brand: "CineStill", defaultIso: 800, evOffset: -0.33, reciprocityFactor: 1.25),
  FilmPreset(name: "Velvia 50", brand: "Fujifilm", defaultIso: 50, evOffset: -0.33, reciprocityFactor: 1.1),
  FilmPreset(name: "Provia 100F", brand: "Fujifilm", defaultIso: 100, evOffset: -0.33, reciprocityFactor: 1.15),
  FilmPreset(name: "HP5 Plus 400", brand: "Ilford", defaultIso: 400, evOffset: 0.0, reciprocityFactor: 1.35),
];

class ShotLog {
  final DateTime timestamp;
  final String filmName;
  final String exposure;
  final double distance;

  ShotLog({required this.timestamp, required this.filmName, required this.exposure, required this.distance});
}

enum PriorityMode { aperture, shutter }

class MainMeterScreen extends StatefulWidget {
  const MainMeterScreen({super.key});

  @override
  State<MainMeterScreen> createState() => _MainMeterScreenState();
}

class _MainMeterScreenState extends State<MainMeterScreen> with TickerProviderStateMixin {
  static const Color brassGold = Color(0xFFE5C158);
  static const Color leicaGreen = Color(0xFF2A4D3B);
  static const Color darkCharcoal = Color(0xFF121413);

  late AnimationController _introController;
  late Animation<double> _titleFadeInAnim;
  late Animation<double> _titleScaleAnim;
  late Animation<double> _splashOverlayFadeOutAnim;
  late Animation<double> _dialRotationAnim;
  late Animation<double> _dialScaleAnim;
  late Animation<double> _apertureApertureAnim;
  late Animation<double> _needleSweepAnim;

  FilmPreset _selectedFilm = kFilmDatabase[0];
  int _selectedIso = 400;
  double _selectedAperture = 5.6;
  double _selectedShutterReciprocal = 125.0;
  PriorityMode _mode = PriorityMode.aperture;

  bool _isLocked = false;
  double _focalLengthMM = 50.0;
  double _targetDistanceM = 2.5;
  double _userEyeHeightM = 1.6;
  double _rawEV100 = 12.0;

  final List<ShotLog> _shotLogs = [];

  final List<double> _apertureList = [1.2, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0];
  final List<double> _shutterList = [4000, 2000, 1000, 500, 250, 125, 60, 30, 15, 8, 4, 2, 1];
  final List<double> _focalList = [28.0, 35.0, 50.0, 85.0, 135.0];

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _titleFadeInAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
    );
    _titleScaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack)),
    );
    _splashOverlayFadeOutAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.45, 0.7, curve: Curves.easeInOut)),
    );

    _dialScaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic)),
    );
    _dialRotationAnim = Tween<double>(begin: -1.2, end: 0.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.5, 0.85, curve: Curves.easeOutBack)),
    );
    _apertureApertureAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.65, 0.95, curve: Curves.easeInOutBack)),
    );
    _needleSweepAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.75, 1.0, curve: Curves.elasticOut)),
    );

    _introController.forward();
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  double get _effectiveEV => _rawEV100 + _selectedFilm.evOffset;

  double get _rawShutterSec {
    double evTarget = _effectiveEV + (log(_selectedIso / 100.0) / ln2);
    return (pow(_selectedAperture, 2)) / pow(2.0, evTarget);
  }

  String get _formattedShutterSpeed {
    double sec = _rawShutterSec;
    if (sec >= 1.0) {
      double correctedSec = pow(sec, _selectedFilm.reciprocityFactor).toDouble();
      return "${correctedSec.toStringAsFixed(1)}s (補正済)";
    } else {
      double reciprocal = 1.0 / sec;
      double closest = _shutterList.reduce((a, b) => (a - reciprocal).abs() < (b - reciprocal).abs() ? a : b);
      return "1/${closest.toInt()}";
    }
  }

  double get _calculatedAperture {
    double evTarget = _effectiveEV + (log(_selectedIso / 100.0) / ln2);
    double shutterSec = 1.0 / _selectedShutterReciprocal;
    double N2 = pow(2.0, evTarget) * shutterSec;
    double calcF = sqrt(max(0.1, N2));
    return _apertureList.reduce((a, b) => (a - calcF).abs() < (b - calcF).abs() ? a : b);
  }

  Map<String, dynamic> get _dofData {
    double f = _focalLengthMM / 1000.0;
    double c = 0.029 / 1000.0;
    double d = _targetDistanceM;
    double currentF = (_mode == PriorityMode.aperture) ? _selectedAperture : _calculatedAperture;

    double h = ((f * f) / (currentF * c)) + f;
    double near = (d * (h - f)) / (h + d - (2 * f));
    double far = (d >= h) ? double.infinity : (d * (h - f)) / (h - d);

    return {
      'hyperfocal': h,
      'near': max(0.0, near),
      'far': far,
      'isHyperfocal': d >= h,
    };
  }

  void _applyZoneFocus() {
    double h = _dofData['hyperfocal'];
    setState(() {
      _targetDistanceM = (h / 2).clamp(0.5, 10.0);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ゾーンフォーカス設定: パンフォーカス（過焦点距離）に合わせました"), duration: Duration(seconds: 2)),
    );
  }

  void _saveShotLog() {
    String expStr = _mode == PriorityMode.aperture ? "f/$_selectedAperture @ $_formattedShutterSpeed" : "f/${_calculatedAperture.toStringAsFixed(1)} @ 1/${_selectedShutterReciprocal.toInt()}";
    setState(() {
      _shotLogs.insert(0, ShotLog(timestamp: DateTime.now(), filmName: "${_selectedFilm.brand} ${_selectedFilm.name}", exposure: expStr, distance: _targetDistanceM));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("撮影データをログに記録しました"), duration: Duration(seconds: 1)),
    );
  }

  void _openRangefinderModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RangefinderFinderWidget(
        userEyeHeight: _userEyeHeightM,
        onDistanceMeasured: (dist) {
          setState(() => _targetDistanceM = dist);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dof = _dofData;
    double ev = _effectiveEV;

    return Scaffold(
      body: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Row(
                children: const [
                  Icon(Icons.camera_rounded, color: brassGold, size: 20),
                  SizedBox(width: 8),
                  Text('LEICA BRASS MASTER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 15, color: brassGold)),
                ],
              ),
              backgroundColor: Colors.black,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: brassGold),
                  onPressed: () => _introController.forward(from: 0.0),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined, color: brassGold),
                  onPressed: _saveShotLog,
                ),
                IconButton(
                  icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: _isLocked ? Colors.redAccent : Colors.grey),
                  onPressed: () => setState(() => _isLocked = !_isLocked),
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: darkCharcoal,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: brassGold.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.movie_filter, color: brassGold, size: 18),
                                    SizedBox(width: 8),
                                    Text("FILM PRESET", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ],
                                ),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<FilmPreset>(
                                    value: _selectedFilm,
                                    dropdownColor: darkCharcoal,
                                    icon: const Icon(Icons.arrow_drop_down, color: brassGold),
                                    onChanged: (film) {
                                      if (film != null) {
                                        setState(() {
                                          _selectedFilm = film;
                                          _selectedIso = film.defaultIso;
                                        });
                                      }
                                    },
                                    items: kFilmDatabase.map((f) {
                                      return DropdownMenuItem(
                                        value: f,
                                        child: Text("${f.brand} ${f.name}", style: const TextStyle(color: brassGold, fontSize: 12, fontWeight: FontWeight.bold)),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          AnimatedBuilder(
                            animation: _introController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _dialScaleAnim.value,
                                child: Transform.rotate(
                                  angle: _dialRotationAnim.value,
                                  child: Container(
                                    height: 250,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF1B1D1C), Color(0xFF0F1110)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(color: brassGold.withOpacity(0.3)),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 16, offset: const Offset(0, 8)),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(240, 240),
                                          painter: LeicaBrassAnimatedDialPainter(
                                            evValue: ev,
                                            apertureProgress: _apertureApertureAnim.value,
                                            needleProgress: _needleSweepAnim.value,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          child: Column(
                                            children: [
                                              Text(
                                                "EV ${ev.toStringAsFixed(1)}",
                                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: brassGold, fontFamily: 'monospace'),
                                              ),
                                              Text("実測: ${_rawEV100.toStringAsFixed(1)} EV | ISO $_selectedIso", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),

                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: brassGold, size: 20),
                                onPressed: _isLocked ? null : () => setState(() => _rawEV100 = max(0.0, _rawEV100 - 0.33)),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _rawEV100,
                                  min: 0.0,
                                  max: 20.0,
                                  divisions: 200,
                                  activeColor: _isLocked ? Colors.grey : brassGold,
                                  onChanged: _isLocked ? null : (val) => setState(() => _rawEV100 = val),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: brassGold, size: 20),
                                onPressed: _isLocked ? null : () => setState(() => _rawEV100 = min(20.0, _rawEV100 + 0.33)),
                              ),
                            ],
                          ),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: darkCharcoal,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("レンジファインダー & DoF", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: _applyZoneFocus,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: leicaGreen, borderRadius: BorderRadius.circular(6)),
                                            child: const Text("パンフォーカス", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: _openRangefinderModal,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(color: brassGold, borderRadius: BorderRadius.circular(6)),
                                            child: const Text("AR距離測定", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                const SizedBox(height: 10),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: _focalList.map((focal) {
                                    final isSelected = focal == _focalLengthMM;
                                    return GestureDetector(
                                      onTap: () => setState(() => _focalLengthMM = focal),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected ? brassGold : const Color(0xFF1E201F),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text("${focal.toInt()}mm", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.white)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),

                                CustomPaint(
                                  size: const Size(double.infinity, 30),
                                  painter: PrecisionLensDoFPainter(near: dof['near'], far: dof['far'], target: _targetDistanceM, accentColor: brassGold),
                                ),
                                const SizedBox(height: 4),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("手前: ${(dof['near'] as double).toStringAsFixed(2)}m", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                    Text("距離: ${_targetDistanceM.toStringAsFixed(2)}m", style: const TextStyle(fontSize: 11, color: brassGold, fontWeight: FontWeight.bold)),
                                    Text("奥: ${dof['far'] == double.infinity ? '∞' : (dof['far'] as double).toStringAsFixed(2) + 'm'}", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -4))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text("Av", style: TextStyle(fontSize: 11)),
                                  selected: _mode == PriorityMode.aperture,
                                  selectedColor: brassGold,
                                  labelStyle: TextStyle(color: _mode == PriorityMode.aperture ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                                  onSelected: (val) => setState(() => _mode = PriorityMode.aperture),
                                ),
                                const SizedBox(width: 6),
                                ChoiceChip(
                                  label: const Text("Tv", style: TextStyle(fontSize: 11)),
                                  selected: _mode == PriorityMode.shutter,
                                  selectedColor: brassGold,
                                  labelStyle: TextStyle(color: _mode == PriorityMode.shutter ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                                  onSelected: (val) => setState(() => _mode = PriorityMode.shutter),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_mode == PriorityMode.aperture ? "Calculated Shutter" : "Calculated Aperture", style: const TextStyle(color: Colors.grey, fontSize: 9)),
                                Text(
                                  _mode == PriorityMode.aperture ? _formattedShutterSpeed : "f/${_calculatedAperture.toStringAsFixed(1)}",
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: brassGold, fontFamily: 'monospace'),
                                ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 8),

                        SizedBox(
                          height: 42,
                          child: _mode == PriorityMode.aperture
                              ? ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _apertureList.length,
                                  itemBuilder: (context, index) {
                                    final f = _apertureList[index];
                                    final isSelected = f == _selectedAperture;
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedAperture = f),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 58,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? brassGold : const Color(0xFF1A1C1B),
                                          borderRadius: BorderRadius.circular(10),
                                          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text("f/$f", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isSelected ? Colors.black : Colors.white)),
                                      ),
                                    );
                                  },
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _shutterList.length,
                                  itemBuilder: (context, index) {
                                    final s = _shutterList[index];
                                    final isSelected = s == _selectedShutterReciprocal;
                                    return GestureDetector(
                                      onTap: () => setState(() => _selectedShutterReciprocal = s),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        width: 64,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected ? brassGold : const Color(0xFF1A1C1B),
                                          borderRadius: BorderRadius.circular(10),
                                          border: isSelected ? Border.all(color: Colors.white, width: 1.5) : null,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text("1/${s.toInt()}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isSelected ? Colors.black : Colors.white)),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          AnimatedBuilder(
            animation: _introController,
            builder: (context, child) {
              if (_splashOverlayFadeOutAnim.value <= 0.0) {
                return const SizedBox.shrink();
              }
              return IgnorePointer(
                child: Opacity(
                  opacity: _splashOverlayFadeOutAnim.value,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: const Color(0xFF0F1110),
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: _titleScaleAnim.value,
                      child: Opacity(
                        opacity: _titleFadeInAnim.value,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: darkCharcoal,
                                border: Border.all(color: brassGold, width: 2),
                                boxShadow: [
                                  BoxShadow(color: brassGold.withOpacity(0.3), blurRadius: 30, spreadRadius: 5),
                                ],
                              ),
                              child: const Icon(Icons.camera, size: 64, color: brassGold),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'LEICA BRASS MASTER',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4.0,
                                color: brassGold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'PROFESSIONAL EXPOSURE & DOF SYSTEM',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 2.0,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class RangefinderFinderWidget extends StatefulWidget {
  final double userEyeHeight;
  final Function(double distanceMeters) onDistanceMeasured;

  const RangefinderFinderWidget({super.key, required this.userEyeHeight, required this.onDistanceMeasured});

  @override
  State<RangefinderFinderWidget> createState() => _RangefinderFinderWidgetState();
}

class _RangefinderFinderWidgetState extends State<RangefinderFinderWidget> {
  double _calculatedDistance = 2.5;
  double _tiltAngleDegree = 40.0;
  late double _eyeHeight;

  @override
  void initState() {
    super.initState();
    _eyeHeight = widget.userEyeHeight;
    _recalculate();
  }

  void _recalculate() {
    double rad = _tiltAngleDegree * pi / 180.0;
    setState(() {
      _calculatedDistance = max(0.3, min(20.0, _eyeHeight * tan(rad)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF121413),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text("AR OPTICAL RANGEFINDER", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Color(0xFFE5C158))),
          const SizedBox(height: 4),
          const Text("被写体の足元（接地点）に十字キーを合わせて距離を測定します", style: TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 16),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5C158).withOpacity(0.5)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.center_focus_weak, size: 100, color: Colors.white10),
                  CustomPaint(
                    size: const Size(180, 180),
                    painter: ReticlePainter(),
                  ),
                  Positioned(
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5C158))),
                      child: Text(
                        "距離: ${_calculatedDistance.toStringAsFixed(2)} m",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFE5C158), fontFamily: 'monospace'),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("カメラ構え高 (アイレベル):", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text("${_eyeHeight.toStringAsFixed(2)}m", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
                  ],
                ),
                Slider(
                  value: _eyeHeight,
                  min: 1.0,
                  max: 2.2,
                  activeColor: const Color(0xFFE5C158),
                  onChanged: (val) {
                    _eyeHeight = val;
                    _recalculate();
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("スマホ傾き角度 (ジャイロ模擬):", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Text("${_tiltAngleDegree.toInt()}°", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                Slider(
                  value: _tiltAngleDegree,
                  min: 10.0,
                  max: 80.0,
                  activeColor: const Color(0xFFE5C158),
                  onChanged: (val) {
                    _tiltAngleDegree = val;
                    _recalculate();
                  },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5C158),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => widget.onDistanceMeasured(_calculatedDistance),
                child: const Text("この距離を計測値として決定", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class LeicaBrassAnimatedDialPainter extends CustomPainter {
  final double evValue;
  final double apertureProgress;
  final double needleProgress;

  LeicaBrassAnimatedDialPainter({
    required this.evValue,
    required this.apertureProgress,
    required this.needleProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 10;
    final innerRadius = outerRadius - 30;

    const brassColor = Color(0xFFE5C158);

    canvas.drawCircle(center, outerRadius, Paint()..color = const Color(0xFF141615));
    canvas.drawCircle(center, outerRadius, Paint()..color = brassColor.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 2);

    final irisRadius = innerRadius - 20;
    final bladeCount = 8;
    final currentOpening = apertureProgress;

    final bladePaint = Paint()
      ..color = const Color(0xFF222524)
      ..style = PaintingStyle.fill;
    final bladeEdgePaint = Paint()
      ..color = brassColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < bladeCount; i++) {
      double angle = (i * 360 / bladeCount) * pi / 180;
      double bladeOffset = irisRadius * (1.0 - (currentOpening * 0.65));

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);

      Path bladePath = Path();
      bladePath.moveTo(bladeOffset, 0);
      bladePath.lineTo(irisRadius, irisRadius * 0.5);
      bladePath.lineTo(irisRadius * 0.8, irisRadius);
      bladePath.close();

      canvas.drawPath(bladePath, bladePaint);
      canvas.drawPath(bladePath, bladeEdgePaint);
      canvas.restore();
    }

    canvas.drawCircle(center, irisRadius * (currentOpening * 0.65), Paint()..color = const Color(0xFF080908));

    final apertures = [1.2, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0];
    for (int i = 0; i < apertures.length; i++) {
      double angle = -140 + (i * 31.0);
      double rad = angle * pi / 180;

      double x1 = center.dx + (outerRadius - 2) * cos(rad);
      double y1 = center.dy + (outerRadius - 2) * sin(rad);
      double x2 = center.dx + (outerRadius - 10) * cos(rad);
      double y2 = center.dy + (outerRadius - 10) * sin(rad);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), Paint()..color = brassColor..strokeWidth = 2.5);

      TextPainter tp = TextPainter(
        text: TextSpan(text: "${apertures[i]}", style: const TextStyle(color: brassColor, fontSize: 11, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      canvas.save();
      canvas.translate(center.dx + (outerRadius - 20) * cos(rad), center.dy + (outerRadius - 20) * sin(rad));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    final shutters = ["4k", "2k", "1k", "500", "250", "125", "60", "30", "15", "8", "4", "2", "1s"];
    for (int i = 0; i < shutters.length; i++) {
      double angle = -140 + (i * 23.0);
      double rad = angle * pi / 180;

      double x1 = center.dx + (innerRadius - 2) * cos(rad);
      double y1 = center.dy + (innerRadius - 2) * sin(rad);
      double x2 = center.dx + (innerRadius - 8) * cos(rad);
      double y2 = center.dy + (innerRadius - 8) * sin(rad);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), Paint()..color = Colors.white70..strokeWidth = 1.5);

      TextPainter tp = TextPainter(
        text: TextSpan(text: shutters[i], style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      canvas.save();
      canvas.translate(center.dx + (innerRadius - 18) * cos(rad), center.dy + (innerRadius - 18) * sin(rad));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    double clampedEV = evValue.clamp(0.0, 20.0);
    double targetAngle = -140 + (clampedEV * 14.0);
    double currentAngle = -140 + (targetAngle - (-140)) * needleProgress;
    double needleRad = currentAngle * pi / 180;

    canvas.drawLine(
      center,
      Offset(center.dx + (outerRadius - 2) * cos(needleRad), center.dy + (outerRadius - 2) * sin(needleRad)),
      Paint()..color = const Color(0xFFFF3B30)..strokeWidth = 3.5..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(center, 8, Paint()..color = brassColor);
    canvas.drawCircle(center, 3, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant LeicaBrassAnimatedDialPainter oldDelegate) => true;
}

class ReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = const Color(0xFFE5C158)..strokeWidth = 1.5..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 25, paint);
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFFFF3B30));

    canvas.drawLine(Offset(center.dx - 40, center.dy), Offset(center.dx - 10, center.dy), paint);
    canvas.drawLine(Offset(center.dx + 10, center.dy), Offset(center.dx + 40, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - 40), Offset(center.dx, center.dy - 10), paint);
    canvas.drawLine(Offset(center.dx, center.dy + 10), Offset(center.dx, center.dy + 40), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PrecisionLensDoFPainter extends CustomPainter {
  final double near;
  final double far;
  final double target;
  final Color accentColor;

  PrecisionLensDoFPainter({required this.near, required this.far, required this.target, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.white.withOpacity(0.08)..style = PaintingStyle.fill;

    RRect trackRRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 10, size.width, 10), const Radius.circular(5));
    canvas.drawRRect(trackRRect, bgPaint);

    double maxScale = 10.0;
    double startX = (near / maxScale).clamp(0.0, 1.0) * size.width;
    double endX = far.isInfinite ? size.width : (far / maxScale).clamp(0.0, 1.0) * size.width;

    Rect dofRect = Rect.fromLTRB(startX, 10, max(startX + 4, endX), 20);
    canvas.drawRect(dofRect, Paint()..color = accentColor.withOpacity(0.7));

    double targetX = (target / maxScale).clamp(0.0, 1.0) * size.width;
    canvas.drawCircle(Offset(targetX, 15), 6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(targetX, 15), 2.5, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant PrecisionLensDoFPainter oldDelegate) => true;
}
