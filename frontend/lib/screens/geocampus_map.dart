import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:eco_collect/constants/kenums.dart';
import 'package:eco_collect/providers/plant_map_provider.dart';
import 'package:eco_collect/providers/user_provider.dart';
import 'package:eco_collect/screens/geocampus_scanner.dart';
import 'package:eco_collect/services/audio_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lottie/lottie.dart' hide Marker;
import 'package:provider/provider.dart';
import 'package:eco_collect/screens/geocampus/plant_data.dart';

class GeoCampusMapScreen extends StatefulWidget {
  const GeoCampusMapScreen({super.key});

  @override
  State<GeoCampusMapScreen> createState() => _GeoCampusMapScreenState();
}

class _GeoCampusMapScreenState extends State<GeoCampusMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // GPS state
  LatLng? _playerPosition;
  double _playerHeading = 0;
  StreamSubscription<Position>? _positionStream;

  // UI state
  bool _isCalibrating = true;
  // Camera follows the player until the user pans the map; the recenter
  // button turns following back on.
  bool _followPlayer = true;
  String? _enteredZoneName;
  Timer? _zoneMessageTimer;

  // Pulse animation for player dot
  late AnimationController _pulseController;

  // Near-plant detection (within 50m the scan button glows)
  String? _nearestPlantId;

  @override
  void initState() {
    super.initState();
    AudioServices.playAudioAccordingToScreen(KenumScreens.map);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<PlantMapProvider>().load();
      if (!mounted) return;
      await _initGps();
      if (mounted) {
        setState(() => _isCalibrating = false);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStream?.cancel();
    _zoneMessageTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GPS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initGps() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnack('GPS is disabled. Please enable location services.');
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _showSnack('Location permission denied.');
      return;
    }

    // Get initial fix
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      _onPosition(pos);
    } catch (_) {}

    if (!mounted) return;
    // Stream updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen(_onPosition, onError: (e) => debugPrint('GPS error: $e'));
  }

  void _onPosition(Position pos) {
    if (!mounted) return;
    final latlng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _playerPosition = latlng;
      // Heading is only meaningful while moving; keep the last one otherwise.
      if (pos.heading.isFinite && pos.heading >= 0 && pos.speed > 0.5) {
        _playerHeading = pos.heading;
      }
    });

    if (_followPlayer) {
      try {
        _mapController.move(latlng, _mapController.camera.zoom);
      } catch (_) {}
    }

    _checkNearbyPlants(latlng);
  }

  void _checkNearbyPlants(LatLng playerPos) {
    final plants = context.read<PlantMapProvider>().plants;
    const Distance distance = Distance();
    String? nearest;
    double minDist = double.infinity;

    for (final plant in plants) {
      if (plant.discovered || plant.position == null) continue;
      final d = distance.as(LengthUnit.Meter, playerPos, plant.position!);
      if (d < 50 && d < minDist) {
        minDist = d;
        nearest = plant.id;
      }
    }

    if (nearest != _nearestPlantId) {
      setState(() => _nearestPlantId = nearest);
      if (nearest != null) {
        final p = plants.firstWhere((x) => x.id == nearest);
        _showZoneMessage('🌿 ${p.commonName} nearby! Scan it!');
      }
    }
  }

  void _showZoneMessage(String message) {
    setState(() => _enteredZoneName = message);
    _zoneMessageTimer?.cancel();
    _zoneMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _enteredZoneName = null);
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── DARK-THEMED FLUTTER MAP ──
          _buildMap(),

          // ── DISCOVERY QUEST BAR ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildQuestBar(),
          ),

          // ── ZONE FLASH MESSAGE ──
          if (_enteredZoneName != null)
            Positioned(
              bottom: 172,
              left: 24,
              right: 24,
              child: _buildZoneMessage(_enteredZoneName!),
            ),

          // ── SCAN FAB ──
          Positioned(
            bottom: 30,
            right: 24,
            child: _buildScanButton(),
          ),

          // ── POKEDEX FAB ──
          Positioned(
            bottom: 30,
            left: 24,
            child: _buildPokedexButton(),
          ),

          // ── RECENTER BUTTON ──
          Positioned(
            bottom: 110,
            right: 24,
            child: _buildRecenterButton(),
          ),

          // ── CALIBRATION OVERLAY ──
          if (_isCalibrating) _buildCalibrationOverlay(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Map widget — dark tiles for gamified look
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return Consumer<PlantMapProvider>(
      builder: (context, plantProvider, _) {
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            // Manouba campus center
            initialCenter: _playerPosition ?? const LatLng(36.8160, 10.0616),
            initialZoom: 17.5,
            maxZoom: 19,
            minZoom: 14,
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followPlayer) {
                setState(() => _followPlayer = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.geocampus.eco_collect',
            ),

            // Plant markers
            MarkerLayer(
              markers: plantProvider.mappablePlants
                  .map((plant) => _buildPlantMarker(plant))
                  .toList(),
            ),

            // Player avatar marker
            if (_playerPosition != null)
              MarkerLayer(
                markers: [_buildPlayerMarker(_playerPosition!)],
              ),
          ],
        );
      },
    );
  }

  Marker _buildPlantMarker(CampusPlant plant) {
    final isNear = plant.id == _nearestPlantId;
    return Marker(
      point: plant.position!,
      width: 56,
      height: 68,
      child: GestureDetector(
        onTap: () => _showPlantInfo(plant),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final scale = isNear
                    ? 1.0 + 0.25 * _pulseController.value
                    : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: plant.discovered
                          ? const Color(0xFF2D6A4F)
                          : isNear
                              ? Colors.orange.shade800
                              : const Color(0xFF1B4332),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: plant.discovered
                            ? Colors.greenAccent
                            : isNear
                                ? Colors.orangeAccent
                                : Colors.white38,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: plant.discovered
                              ? Colors.greenAccent.withValues(alpha: 0.6)
                              : isNear
                                  ? Colors.orange.withValues(alpha: 0.6)
                                  : Colors.cyan.withValues(alpha: 0.2),
                          blurRadius: isNear ? 16 : 10,
                          spreadRadius: isNear ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        plant.discovered ? '✅' : '🌿',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                );
              },
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: plant.discovered
                      ? Colors.greenAccent.withValues(alpha: 0.3)
                      : Colors.white12,
                ),
              ),
              child: Text(
                plant.commonName,
                style: TextStyle(
                  color: plant.discovered ? Colors.greenAccent : Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Marker _buildPlayerMarker(LatLng pos) {
    return Marker(
      point: pos,
      width: 64,
      height: 80,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (_, __) {
          final pulse = _pulseController.value;
          return CustomPaint(
            size: const Size(64, 80),
            painter: _AvatarPainter(
              pulseValue: pulse,
              heading: _playerHeading,
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Discovery Quest Bar (gamified HUD)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildQuestBar() {
    final user = context.watch<UserDataProvider>().getUserData;
    final plantProvider = context.watch<PlantMapProvider>();
    final discovered = plantProvider.questDiscovered;
    final total = plantProvider.questTotal;
    final progress = total > 0 ? discovered / total : 0.0;
    final xp = user?.xp ?? 0;
    final level = xp ~/ 1000 + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withValues(alpha: 0.15),
            blurRadius: 16,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Level badge
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2D6A4F), Color(0xFF40916C)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.greenAccent, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (user?.fullName ?? 'ECO EXPLORER').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '🌿 DISCOVER $discovered/$total SPECIES',
                      style: TextStyle(
                        color: Colors.greenAccent.shade200,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // XP counter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$xp XP',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quest progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Colors.greenAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Zone message banner
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildZoneMessage(String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade900.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.orangeAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.4),
              blurRadius: 20,
            )
          ],
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.3, end: 0, duration: 300.ms),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scan FAB
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildScanButton() {
    final isNear = _nearestPlantId != null;
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final scale = isNear ? 1.0 + 0.08 * _pulseController.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _openScanner,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isNear
                      ? [Colors.orange, Colors.deepOrangeAccent]
                      : [const Color(0xFF2D6A4F), const Color(0xFF40916C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: (isNear ? Colors.orange : Colors.greenAccent)
                        .withValues(alpha: 0.5),
                    blurRadius: 18,
                    spreadRadius: 3,
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: isNear ? 30 : 26,
                  ),
                  const Text(
                    'SCAN',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecenterButton() {
    return GestureDetector(
      onTap: () {
        setState(() => _followPlayer = true);
        if (_playerPosition != null) {
          _mapController.move(_playerPosition!, 17.5);
        } else {
          _showSnack('Waiting for a GPS fix...');
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black87,
          shape: BoxShape.circle,
          border: Border.all(
              color: _followPlayer ? Colors.cyanAccent : Colors.white24),
        ),
        child: Icon(
          _followPlayer ? Icons.my_location : Icons.location_searching,
          color: Colors.cyanAccent,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildPokedexButton() {
    return GestureDetector(
      onTap: () => _showEncyclopedia(context),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
        ),
        child: const Center(
          child: Text('📖', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }

  // ── ENCYCLOPEDIA MODAL ──
  void _showEncyclopedia(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Consumer<PlantMapProvider>(
              builder: (sheetContext, plantProvider, _) {
            final dynamicPlants = plantProvider.discoveredSpecies;
            final totalCards =
                math.max(plantProvider.questTotal, dynamicPlants.length + 3);

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF020617),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Text(
                    'POKÉDEX : CAMPUS FLORA',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Gotta scan \'em all!', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: totalCards,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemBuilder: (context, index) {
                        final isDiscovered = index < dynamicPlants.length;
                        final plant = isDiscovered ? dynamicPlants[index] : null;

                        return GestureDetector(
                          onTap: isDiscovered ? () {
                            Navigator.pop(sheetContext);
                            _showPlantInfo(plant!);
                          } : null,
                          child: Container(
                            decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDiscovered
                                ? [const Color(0xFF112A46), const Color(0xFF0F172A)]
                                : [const Color(0xFF1A1A1A), const Color(0xFF0A0A0A)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDiscovered ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.white10,
                              width: isDiscovered ? 2 : 1,
                            ),
                            boxShadow: isDiscovered ? [
                              BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)
                            ] : [],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Top header (ID)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDiscovered ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.black26,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                                ),
                                child: Text(
                                  '#${(index + 1).toString().padLeft(3, '0')}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: isDiscovered ? Colors.blueAccent : Colors.white38, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              // Avatar
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: isDiscovered ? Colors.white10 : Colors.black45,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDiscovered ? Colors.greenAccent : Colors.white12, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    isDiscovered ? '🌿' : '❓',
                                    style: TextStyle(fontSize: 32, color: isDiscovered ? Colors.white : Colors.white24),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Info
                              Text(
                                isDiscovered ? plant!.commonName : 'Unknown Species',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDiscovered ? Colors.white : Colors.white38,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (isDiscovered) ...[
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    plant!.scientificName.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                            ],
                          ),
                        ));
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Plant info bottom sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _showPlantInfo(CampusPlant plant) {
    Plant? backendData;
    try {
      backendData = plantList.firstWhere(
        (p) => p.name.toLowerCase() == plant.commonName.toLowerCase() ||
               p.name.toLowerCase() == plant.scientificName.toLowerCase()
      );
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE HEADER (the local photo may have been cleaned up by the OS)
            if (plant.scanImageUrl != null &&
                File(plant.scanImageUrl!).existsSync())
              Container(
                width: double.infinity,
                height: 200,
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 5))
                  ]
                ),
                child: Image.file(
                  File(plant.scanImageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // TITLE ROW
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: plant.discovered
                        ? const Color(0xFF2D6A4F)
                        : Colors.grey.shade800,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: plant.discovered
                            ? Colors.greenAccent.withValues(alpha: 0.3)
                            : Colors.transparent,
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      plant.discovered ? '✅' : '🌿',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant.commonName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        plant.scientificName,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // BACKEND PROPERTIES (if found)
            if (backendData != null) ...[
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: Colors.black26,
                   borderRadius: BorderRadius.circular(16),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text('Type: ${backendData.type}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                     const SizedBox(height: 8),
                     Text('Characteristics: ${backendData.characteristics}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                     const SizedBox(height: 8),
                     Text('Environment: ${backendData.environment}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                   ]
                 ),
               ),
               const SizedBox(height: 16),
            ],
            if (plant.discovered && plant.confidence != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Identified with ${(plant.confidence! * 100).toStringAsFixed(1)}% confidence',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else if (!plant.discovered)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openScanner(targetPlantId: plant.id);
                },
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan This Plant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D6A4F),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  void _openScanner({String? targetPlantId}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeoCampusScannerScreen(
          playerPosition: _playerPosition,
          targetPlantId: targetPlantId ?? _nearestPlantId,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Calibration overlay
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCalibrationOverlay() {
    return Container(
      color: const Color(0xFF020617),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lottie/seed_grow_loading.json',
            height: 180,
            errorBuilder: (_, __, ___) =>
                const CircularProgressIndicator(color: Colors.greenAccent),
          ),
          const SizedBox(height: 28),
          const Text(
            'LOADING CAMPUS MAP',
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'SYNCING GPS & PLANT DATA...',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 2.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom avatar painter — draws a polished player character on the map
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarPainter extends CustomPainter {
  final double pulseValue;
  final double heading;

  _AvatarPainter({required this.pulseValue, required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.55;

    // ── Shadow ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height - 8),
        width: 28 + 4 * pulseValue,
        height: 8,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35 - 0.1 * pulseValue),
    );

    // ── Outer pulse aura ──
    final auraRadius = 22.0 + 8.0 * pulseValue;
    canvas.drawCircle(
      Offset(cx, cy),
      auraRadius,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15 * (1 - pulseValue))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // ── Accuracy ring ──
    canvas.drawCircle(
      Offset(cx, cy),
      20.0,
      Paint()
        ..color = const Color(0xFF29B6F6).withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Body gradient circle ──
    final bodyRadius = 16.0;
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFF40C4FF), Color(0xFF0077CC)],
        center: Alignment(-0.3, -0.3),
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: bodyRadius),
      );
    canvas.drawCircle(Offset(cx, cy), bodyRadius, bodyPaint);

    // ── White border ──
    canvas.drawCircle(
      Offset(cx, cy),
      bodyRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // ── Inner face ──
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - 4.5, cy - 3), 2.5, eyePaint);
    canvas.drawCircle(Offset(cx + 4.5, cy - 3), 2.5, eyePaint);
    final pupilPaint = Paint()..color = const Color(0xFF003366);
    canvas.drawCircle(Offset(cx - 4.5, cy - 3), 1.2, pupilPaint);
    canvas.drawCircle(Offset(cx + 4.5, cy - 3), 1.2, pupilPaint);

    // Smile
    final smilePath = Path()
      ..moveTo(cx - 4, cy + 3)
      ..quadraticBezierTo(cx, cy + 7, cx + 4, cy + 3);
    canvas.drawPath(
      smilePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // ── Direction triangle ──
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(heading * math.pi / 180);
    canvas.translate(0, -bodyRadius - 4);
    final arrowPaint = Paint()
      ..color = const Color(0xFF40C4FF)
      ..style = PaintingStyle.fill;
    final arrow = Path()
      ..moveTo(0, -6)
      ..lineTo(-4, 0)
      ..lineTo(4, 0)
      ..close();
    canvas.drawPath(arrow, arrowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.pulseValue != pulseValue || old.heading != heading;
}
