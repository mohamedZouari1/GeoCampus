import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single plant point-of-interest on the campus map.
class CampusPlant {
  final String id;
  final String commonName;
  final String scientificName;
  /// `null` for free scans made without a GPS fix (shown in the Pokédex only).
  final LatLng? position;
  bool discovered;
  String? scanImageUrl; // PlantNet returned image URL (optional)
  double? confidence;

  CampusPlant({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.position,
    this.discovered = false,
    this.scanImageUrl,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'commonName': commonName,
        'scientificName': scientificName,
        'lat': position?.latitude,
        'lng': position?.longitude,
        'discovered': discovered,
        'scanImageUrl': scanImageUrl,
        'confidence': confidence,
      };

  factory CampusPlant.fromJson(Map<String, dynamic> j) => CampusPlant(
        id: j['id'],
        commonName: j['commonName'],
        scientificName: j['scientificName'],
        position: j['lat'] == null || j['lng'] == null
            ? null
            : LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        discovered: j['discovered'] ?? false,
        scanImageUrl: j['scanImageUrl'],
        confidence: (j['confidence'] as num?)?.toDouble(),
      );

  CampusPlant copy() => CampusPlant.fromJson(toJson());
}

class PlantMapProvider extends ChangeNotifier {
  static const _kKey = 'campus_plants_v2'; // bumped version to force reload

  List<CampusPlant> _plants = [];
  List<CampusPlant> get plants => _plants;

  Set<String> _unlockedSpecies = {};
  Set<String> get unlockedSpecies => _unlockedSpecies;

  /// Plants that can be drawn on the map (have a GPS position).
  Iterable<CampusPlant> get mappablePlants =>
      _plants.where((p) => p.position != null);

  /// One discovered plant per species, in discovery order (for the Pokédex).
  List<CampusPlant> get discoveredSpecies {
    final seen = <String>{};
    final out = <CampusPlant>[];
    for (final p in _plants) {
      if (p.discovered && seen.add(p.scientificName.toLowerCase())) {
        out.add(p);
      }
    }
    return out;
  }

  int get totalDiscovered => _plants.where((p) => p.discovered).length;

  /// Quest progress counts only the pre-seeded campus plants, so free scans
  /// can't push the counter past 100%.
  Iterable<CampusPlant> get _questPlants =>
      _plants.where((p) => !p.id.startsWith('free_'));
  int get questTotal => _questPlants.length;
  int get questDiscovered => _questPlants.where((p) => p.discovered).length;

  bool isSpeciesNew(String scientificName) {
    return !_unlockedSpecies.contains(scientificName);
  }

  Future<void> markSpeciesUnlocked(String scientificName) async {
    _unlockedSpecies.add(scientificName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('${_kKey}_pokedex', _unlockedSpecies.toList());
    notifyListeners();
  }

  // ── Real Manouba Campus plant locations ──────────────────────────────────
  // Campus center: 36.8160°N, 10.0616°E
  // Built fresh each time so mutating a plant never corrupts the defaults.
  static List<CampusPlant> _freshDefaults() => [
    // ── Trees ──
    CampusPlant(
      id: 'olive_1',
      commonName: 'Olive Tree',
      scientificName: 'Olea europaea',
      position: const LatLng(36.81620, 10.06200),
    ),
    CampusPlant(
      id: 'olive_2',
      commonName: 'Wild Olive',
      scientificName: 'Olea europaea var. sylvestris',
      position: const LatLng(36.81580, 10.06280),
    ),
    CampusPlant(
      id: 'palm_1',
      commonName: 'Date Palm',
      scientificName: 'Phoenix dactylifera',
      position: const LatLng(36.81550, 10.06150),
    ),
    CampusPlant(
      id: 'palm_2',
      commonName: 'Canary Island Palm',
      scientificName: 'Phoenix canariensis',
      position: const LatLng(36.81690, 10.06260),
    ),
    CampusPlant(
      id: 'fig_1',
      commonName: 'Common Fig',
      scientificName: 'Ficus carica',
      position: const LatLng(36.81680, 10.06100),
    ),
    CampusPlant(
      id: 'orange_1',
      commonName: 'Orange Tree',
      scientificName: 'Citrus sinensis',
      position: const LatLng(36.81700, 10.06180),
    ),
    CampusPlant(
      id: 'lemon_1',
      commonName: 'Lemon Tree',
      scientificName: 'Citrus limon',
      position: const LatLng(36.81640, 10.06320),
    ),
    CampusPlant(
      id: 'eucalyptus_1',
      commonName: 'Eucalyptus',
      scientificName: 'Eucalyptus globulus',
      position: const LatLng(36.81750, 10.06120),
    ),
    CampusPlant(
      id: 'pine_1',
      commonName: 'Aleppo Pine',
      scientificName: 'Pinus halepensis',
      position: const LatLng(36.81720, 10.06050),
    ),
    CampusPlant(
      id: 'cypress_1',
      commonName: 'Mediterranean Cypress',
      scientificName: 'Cupressus sempervirens',
      position: const LatLng(36.81560, 10.06080),
    ),
    CampusPlant(
      id: 'carob_1',
      commonName: 'Carob Tree',
      scientificName: 'Ceratonia siliqua',
      position: const LatLng(36.81600, 10.06350),
    ),
    CampusPlant(
      id: 'mulberry_1',
      commonName: 'White Mulberry',
      scientificName: 'Morus alba',
      position: const LatLng(36.81670, 10.06380),
    ),

    // ── Shrubs & Flowers ──
    CampusPlant(
      id: 'jasmine_1',
      commonName: 'Jasmine',
      scientificName: 'Jasminum officinale',
      position: const LatLng(36.81590, 10.06250),
    ),
    CampusPlant(
      id: 'rosemary_1',
      commonName: 'Rosemary',
      scientificName: 'Salvia rosmarinus',
      position: const LatLng(36.81650, 10.06050),
    ),
    CampusPlant(
      id: 'bougainvillea_1',
      commonName: 'Bougainvillea',
      scientificName: 'Bougainvillea spectabilis',
      position: const LatLng(36.81530, 10.06300),
    ),
    CampusPlant(
      id: 'oleander_1',
      commonName: 'Oleander',
      scientificName: 'Nerium oleander',
      position: const LatLng(36.81710, 10.06300),
    ),
    CampusPlant(
      id: 'lavender_1',
      commonName: 'Lavender',
      scientificName: 'Lavandula angustifolia',
      position: const LatLng(36.81540, 10.06200),
    ),
    CampusPlant(
      id: 'prickly_pear_1',
      commonName: 'Prickly Pear',
      scientificName: 'Opuntia ficus-indica',
      position: const LatLng(36.81760, 10.06220),
    ),
    CampusPlant(
      id: 'aloe_1',
      commonName: 'Aloe Vera',
      scientificName: 'Aloe barbadensis',
      position: const LatLng(36.81500, 10.06160),
    ),
    CampusPlant(
      id: 'pomegranate_1',
      commonName: 'Pomegranate',
      scientificName: 'Punica granatum',
      position: const LatLng(36.81630, 10.06400),
    ),
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load unlocked Pokedex database
    final unlocked = prefs.getStringList('${_kKey}_pokedex');
    if (unlocked != null) {
      _unlockedSpecies = unlocked.toSet();
    }

    final raw = prefs.getString(_kKey);
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        _plants = decoded.map((e) => CampusPlant.fromJson(e)).toList();
      } catch (_) {
        _plants = _freshDefaults();
      }
    } else {
      _plants = _freshDefaults();
    }
    notifyListeners();
  }

  /// Marks a pre-seeded plant as discovered. Its name is kept: the scanner
  /// only calls this when the scan matched the plant's species.
  Future<void> markDiscovered({
    required String plantId,
    double? confidence,
    String? imageUrl,
  }) async {
    final idx = _plants.indexWhere((p) => p.id == plantId);
    if (idx == -1) return;
    _plants[idx]
      ..discovered = true
      ..confidence = confidence
      ..scanImageUrl = imageUrl;
    notifyListeners();
    await _persist();
  }

  /// Call after a successful PlantNet scan at the player's current GPS position.
  /// Adds an ad-hoc discovered plant if the player isn't near any pre-seeded one.
  Future<void> addFreeDiscovery({
    required LatLng? position,
    required String commonName,
    required String scientificName,
    double? confidence,
    String? imageUrl,
  }) async {
    final id = 'free_${DateTime.now().millisecondsSinceEpoch}';
    _plants.add(CampusPlant(
      id: id,
      commonName: commonName,
      scientificName: scientificName,
      position: position,
      discovered: true,
      confidence: confidence,
      scanImageUrl: imageUrl,
    ));
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, jsonEncode(_plants.map((p) => p.toJson()).toList()));
  }

  Future<void> reset() async {
    _plants = _freshDefaults();
    _unlockedSpecies = {};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_kKey}_pokedex');
    await _persist();
  }
}
