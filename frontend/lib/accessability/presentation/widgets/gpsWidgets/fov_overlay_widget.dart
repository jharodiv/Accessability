// fov_overlay_widget.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// FOV overlay that simulates a radial gradient cone using stacked concentric
/// sector polygons (inner = bold purple, outer = light). Uses static zoom
/// buckets to avoid heavy work while pinch-zooming.
class FovOverlay extends StatefulWidget {
  final LatLng? Function() getCurrentLocation;
  final Stream<LatLng>? locationStream;
  final void Function(Set<Polygon>) onPolygonsChanged;

  /// New: optional listenable (fast, immediate) for map zoom changes.
  /// If provided, it will be used instead of polling getMapZoom().
  final ValueListenable<double>? mapZoomListenable;

  /// Backwards-compatible getter. Kept for callers that prefer a simple getter.
  final double Function()? getMapZoom;

  final double minZoomToShow;
  final double fovAngle;
  final Color color;
  final int pollIntervalMs;

  // visual tuning (pixel radii used for buckets; converted to meters at bucket-change time)
  final double largeBeamPx;
  final double mediumBeamPx;
  final double smallBeamPx;
  final int steps; // max steps (per polygon around arc)
  final double zoomCutLarge;
  final double zoomCutSmall;

  // Gradient tuning: number of concentric layers used to simulate gradient
  final int gradientLayers;
  // start (inner) opacity and end (outer) opacity
  final double startOpacity;
  final double endOpacity;

  const FovOverlay({
    Key? key,
    required this.getCurrentLocation,
    required this.onPolygonsChanged,
    this.locationStream,
    this.getMapZoom,
    this.mapZoomListenable,
    this.minZoomToShow = -1.0,
    this.fovAngle = 40.0,
    this.color = const Color(0xFF7C4DFF),
    this.pollIntervalMs = 500,
    this.largeBeamPx = 220.0,
    this.mediumBeamPx = 140.0,
    this.smallBeamPx = 80.0,
    this.steps = 18,
    this.zoomCutLarge = 12.0,
    this.zoomCutSmall = 16.0,
    this.gradientLayers = 12,
    // LIGHTER DEFAULTS
    this.startOpacity = 0.36, // inner (was 0.92)
    this.endOpacity = 0.02, // outer (was 0.06)
  }) : super(key: key);

  @override
  _FovOverlayState createState() => _FovOverlayState();
}

class _FovOverlayState extends State<FovOverlay> {
  StreamSubscription<CompassEvent?>? _compassSub;
  StreamSubscription<LatLng>? _locSub;
  Timer? _pollTimer;
  Timer? _zoomWatchTimer;
  VoidCallback? _zoomListener; // listener for ValueListenable

  // heading / location
  double _heading = 0.0;
  LatLng? _lastLocation;

  // polygon cache used for equality checks
  Set<Polygon> _polygons = {};

  // throttles
  final double _headingThresholdDeg = 3.0;
  final double _locationThresholdMeters = 3.0;
  final int _minIntervalMs = 60; // allow modest rate
  int _lastUpdateMs = 0;

  bool _zoomVisible = true;
  double? _lastSeenZoom;
  int? _lastZoomBucket; // 0=large,1=mid,2=small

  // current radius in meters (static per bucket until bucket changes)

  // debug prints toggle
  final bool _debug = false;

  // Throttle zoom-triggered recomputes so super-fast pinch updates don't blow CPU.
  final int _zoomRecomputeThrottleMs = 50;
  int _lastZoomRecomputeMs = 0;
  // current radius in meters (static per bucket until bucket changes)
  double _currentRadiusMeters = 0.0;

  // Once true we will NOT update radius from zoom changes (fixed-beam mode).
  bool _beamLocked = false;

  double _maxRadiusMeters = double.infinity;

  @override
  void initState() {
    super.initState();

    // Compass events
    try {
      _compassSub = FlutterCompass.events?.listen((event) {
        final raw = (event?.heading ?? 0.0).toDouble();
        if (raw.isNaN) return;
        _maybeRecompute(heading: raw);
      });
    } catch (_) {}

    // Location updates
    if (widget.locationStream != null) {
      _locSub = widget.locationStream!.listen((latlng) {
        _maybeRecompute(location: latlng);
      });
    } else {
      _pollTimer =
          Timer.periodic(Duration(milliseconds: widget.pollIntervalMs), (_) {
        _maybeRecompute();
      });
    }

    // If a listenable zoom is provided, attach a listener for immediate updates.
    if (widget.mapZoomListenable != null) {
      _zoomListener = () {
        final double z = widget.mapZoomListenable!.value;
        _onExternalZoom(z);
      };
      widget.mapZoomListenable!.addListener(_zoomListener!);
      // seed lastSeen zoom immediately
      _lastSeenZoom = widget.mapZoomListenable!.value;
    } else {
      // Watch zoom if getter provided (infrequent check) - fallback
      if (widget.getMapZoom != null) {
        _zoomWatchTimer =
            Timer.periodic(Duration(milliseconds: 250), (_) => _checkZoom());
        _checkZoom();
      }
    }

    // initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeRecompute(force: true);
    });
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _locSub?.cancel();
    _pollTimer?.cancel();
    _zoomWatchTimer?.cancel();
    if (widget.mapZoomListenable != null && _zoomListener != null) {
      try {
        widget.mapZoomListenable!.removeListener(_zoomListener!);
      } catch (_) {}
    }
    super.dispose();
  }

  // Called when external listenable provides an immediate zoom change.
  void _onExternalZoom(double z) {
    try {
      // small jitter guard
      if (_lastSeenZoom != null && (z - _lastSeenZoom!).abs() < 0.01) {
        _lastSeenZoom = z;
        return;
      }

      // visibility toggle handling
      if (widget.minZoomToShow > 0) {
        final shouldBeVisible = z >= widget.minZoomToShow;
        if (shouldBeVisible != _zoomVisible) {
          _zoomVisible = shouldBeVisible;
          if (!_zoomVisible) {
            _updatePolygons({});
            return;
          } else {
            _maybeRecompute(force: true);
            _lastSeenZoom = z;
            return;
          }
        }
      }

      final int bucket = _bucketForZoom(z);

      // recompute radius per-bucket but also allow smooth updates within bucket.
      // bucket change triggers a heavy "updateRadiusForBucket" + rebuild.
      if (_lastZoomBucket == null || _lastZoomBucket != bucket) {
        if (_debug)
          debugPrint('FOV: bucket change ${_lastZoomBucket} -> $bucket');
        _lastZoomBucket = bucket;
        _lastSeenZoom = z;
        _updateRadiusForBucket(
            bucket); // sets _currentRadiusMeters using px constant
        _buildGradientCone(_currentRadiusMeters);
        return;
      }

      // Otherwise bucket didn't change: recompute dynamic radius that follows zoom.
      final int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastZoomRecomputeMs < _zoomRecomputeThrottleMs) {
        _lastSeenZoom = z;
        return;
      }
      _lastZoomRecomputeMs = now;
      _lastSeenZoom = z;

      // Recompute radius by converting px->meters using current zoom (so it scales smoothly)
// Recompute radius by converting px->meters using current zoom (so it scales smoothly)
      final LatLng? center = _lastLocation ?? widget.getCurrentLocation();
      if (center != null) {
        // choose px from the current bucket for visual consistency
        double px;
        if (bucket == 0)
          px = widget.largeBeamPx;
        else if (bucket == 1)
          px = widget.mediumBeamPx;
        else
          px = widget.smallBeamPx;

        final double mpp = _metersPerPixel(center.latitude, z);
        final double computedMeters = (px * mpp).clamp(10.0, 350000.0);

        // initialize max if unset (first meaningful measurement)
        if (_maxRadiusMeters == double.infinity) {
          _maxRadiusMeters = computedMeters;
        }

        // allow shrink (computed < max) but never grow above _maxRadiusMeters
        _currentRadiusMeters = math.min(computedMeters, _maxRadiusMeters);

        _buildGradientCone(_currentRadiusMeters);
      } else {
        _maybeRecompute(force: true);
      }
    } catch (e) {
      if (_debug) debugPrint('FOV external zoom error: $e');
    }
  }

  void resetBeamSizing() {
    _maxRadiusMeters = double.infinity;
    _currentRadiusMeters = 0.0;
    _lastZoomBucket = null;
    _maybeRecompute(force: true);
  }

  // ---- simplified zoom handling: only react when zoom bucket changes ----
  void _checkZoom() {
    if (widget.getMapZoom == null) return;
    try {
      final z = widget.getMapZoom!();

      // visibility toggle
      if (widget.minZoomToShow > 0) {
        final shouldBeVisible = z >= widget.minZoomToShow;
        if (shouldBeVisible != _zoomVisible) {
          _zoomVisible = shouldBeVisible;
          if (!_zoomVisible) {
            _updatePolygons({});
            return;
          } else {
            _maybeRecompute(force: true);
            return;
          }
        }
      }

      // small jitter guard
      if (_lastSeenZoom != null && (z - _lastSeenZoom!).abs() < 0.02) {
        _lastSeenZoom = z; // update but don't trigger bucket change
        return;
      }

      _lastSeenZoom = z;

      final int bucket = _bucketForZoom(z);
      if (_lastZoomBucket == null || _lastZoomBucket != bucket) {
        if (_debug)
          debugPrint('FOV: bucket change ${_lastZoomBucket} -> $bucket');
        _lastZoomBucket = bucket;
        _updateRadiusForBucket(bucket);
        // rebuild polygons with the new static radius
        _buildGradientCone(_currentRadiusMeters);
      }
    } catch (e) {
      if (_debug) debugPrint('FOV zoom check error: $e');
    }
  }

  int _bucketForZoom(double zoom) {
    if (zoom <= widget.zoomCutLarge) return 0;
    if (zoom >= widget.zoomCutSmall) return 2;
    return 1;
  }

  /// Convert pixels -> meters using web mercator approximation.
  double _metersPerPixel(double lat, double zoom) {
    final double latRad = (lat * math.pi) / 180.0;
    return 156543.03392 * math.cos(latRad) / math.pow(2.0, zoom);
  }

  /// Pick a static radius (meters) for a chosen bucket and center location.
  /// This is done only when bucket changes so we avoid per-frame work.
  void _updateRadiusForBucket(int bucket) {
    final LatLng? center = _lastLocation ?? widget.getCurrentLocation();
    if (center == null) {
      _maybeRecompute(force: true);
      return;
    }

    // use lastSeenZoom or midpoint if unknown
    final double zoom =
        _lastSeenZoom ?? (widget.zoomCutLarge + widget.zoomCutSmall) / 2.0;

    double px;
    if (bucket == 0)
      px = widget.largeBeamPx;
    else if (bucket == 1)
      px = widget.mediumBeamPx;
    else
      px = widget.smallBeamPx;

    final double mpp = _metersPerPixel(center.latitude, zoom);
    final double computedMeters = (px * mpp).clamp(10.0, 350000.0);

    // If max hasn't been set yet, initialize it from this bucket,
    // otherwise keep the existing _maxRadiusMeters.
    if (_maxRadiusMeters == double.infinity) {
      _maxRadiusMeters = computedMeters;
    }

    // Current radius follows computedMeters but never exceeds the stored max.
    _currentRadiusMeters = math.min(computedMeters, _maxRadiusMeters);

    if (_debug)
      debugPrint(
          'FOV bucket $bucket -> px:$px mpp:${mpp.toStringAsFixed(2)} computed:${computedMeters.toStringAsFixed(2)} max:$_maxRadiusMeters current:$_currentRadiusMeters');

    _buildGradientCone(_currentRadiusMeters);
  }

  void _maybeRecompute(
      {double? heading, LatLng? location, bool force = false}) {
    if (widget.getMapZoom != null &&
        widget.minZoomToShow > 0 &&
        !_zoomVisible) {
      _updatePolygons({});
      return;
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    if (!force && (now - _lastUpdateMs < _minIntervalMs)) return;

    final LatLng? curLoc = location ?? widget.getCurrentLocation();
    if (curLoc == null) {
      _updatePolygons({});
      return;
    }

    final double useHeading = heading ?? _heading;
    final double headingDelta = (useHeading - _heading).abs();

    double locationDeltaMeters = double.infinity;
    if (_lastLocation != null) {
      locationDeltaMeters = _haversineDistanceMeters(_lastLocation!, curLoc);
    }

    final bool shouldUpdate = force ||
        (_lastLocation == null) ||
        headingDelta >= _headingThresholdDeg ||
        locationDeltaMeters >= _locationThresholdMeters;

    if (!shouldUpdate) return;

    _heading = useHeading;
    _lastLocation = curLoc;
    _lastUpdateMs = now;

    // ensure we have a radius for the current bucket; if not, compute it
    if (_currentRadiusMeters <= 0.0) {
      final int bucket = _bucketForZoom(
          _lastSeenZoom ?? (widget.zoomCutLarge + widget.zoomCutSmall) / 2.0);
      _lastZoomBucket = bucket;
      _updateRadiusForBucket(bucket);
    }

    // Build polygons immediately with the (static) current radius.
    _buildGradientCone(_currentRadiusMeters);
  }

  /// Build a gradient cone by stacking [widget.gradientLayers] concentric
  /// sector polygons from inner (bold) to outer (faint). No outlines/strokes.
  void _buildGradientCone(double radiusMeters) {
    final LatLng? userLoc = _lastLocation ?? widget.getCurrentLocation();
    if (userLoc == null) {
      _updatePolygons({});
      return;
    }

    // compute half angle
    final double halfAngle = (widget.fovAngle / 2.0).clamp(1.0, 170.0);

    final Set<Polygon> next = {};

    final int layers = widget.gradientLayers.clamp(1, 48); // limit size
    // We'll create layers from innerIndex = 0 (small radius, high opacity)
    // to outerIndex = layers-1 (full radius, low opacity).
    for (int layerIndex = 0; layerIndex < layers; layerIndex++) {
      // t runs 0..1 from inner -> outer
      final double t = layerIndex / (layers - 1).clamp(1, double.infinity);

      // radius for this layer: small inner -> full outer
      final double layerRadius = radiusMeters * ((layerIndex + 1) / layers);

      // To avoid tiny inner polygons being effectively invisible, ensure minimum fraction:
      final double minFrac = 0.05;
      final double safeRadius = radiusMeters *
          (minFrac + (1 - minFrac) * ((layerIndex + 1) / layers));

      final double usedRadius = safeRadius.clamp(2.0, radiusMeters);

      // opacity interpolation: startOpacity (inner) -> endOpacity (outer)
      final double opacity =
          widget.startOpacity * (1 - t) + widget.endOpacity * t;

      // Build points for this sector
      final pts = _createSectorPoints(
        userLoc,
        _heading,
        halfAngle,
        usedRadius,
        steps: _adaptiveSteps(usedRadius, userLoc),
      );

      next.add(Polygon(
        polygonId: PolygonId('fov_gradient_layer_$layerIndex'),
        points: pts,
        fillColor: widget.color.withOpacity(opacity),
        strokeColor: Colors.transparent,
        strokeWidth: 0,
        zIndex: 100 + layerIndex, // ensure layers draw in order
        consumeTapEvents: false,
        geodesic: true,
      ));
    }

    _updatePolygons(next);
  }

  /// Choose number of polygon steps based on on-screen px radius.
  /// Coarser than before to reduce trig cost.
  int _adaptiveSteps(double radiusMeters, LatLng userLoc) {
    // Use lastSeenZoom if available.
    final double zoom =
        _lastSeenZoom ?? (widget.zoomCutLarge + widget.zoomCutSmall) / 2.0;
    final double mpp = _metersPerPixel(userLoc.latitude, zoom);
    final double px = (radiusMeters / (mpp == 0 ? 1.0 : mpp)).abs();

    // Coarser: ~1 vertex per ~32 px (lighter CPU)
    final int raw = (px / 32.0).round();
    // cap to 6..min(widget.steps, 20)
    final int maxSteps = widget.steps < 20 ? widget.steps : 20;
    return raw.clamp(6, maxSteps);
  }

  /// Replace previous _updatePolygons with geometry-aware comparison to ensure map gets updates.
  void _updatePolygons(Set<Polygon> next) {
    // Quick path: if counts differ, update
    if (_polygons.length != next.length) {
      _polygons = next;
      widget.onPolygonsChanged(_polygons);
      if (_debug) debugPrint('FOV: update (count changed)');
      return;
    }

    // map by id
    final Map<String, Polygon> oldById = {
      for (final p in _polygons) p.polygonId.value: p
    };
    final Map<String, Polygon> newById = {
      for (final p in next) p.polygonId.value: p
    };

    // id set changed?
    if (!Set.from(oldById.keys).containsAll(newById.keys) ||
        !Set.from(newById.keys).containsAll(oldById.keys)) {
      _polygons = next;
      widget.onPolygonsChanged(_polygons);
      if (_debug) debugPrint('FOV: update (ids changed)');
      return;
    }

    bool pointsEqual(List<LatLng> a, List<LatLng> b) {
      if (a.length != b.length) return false;
      const double eps = 1e-6;
      for (int i = 0; i < a.length; i++) {
        if ((a[i].latitude - b[i].latitude).abs() > eps ||
            (a[i].longitude - b[i].longitude).abs() > eps) return false;
      }
      return true;
    }

    for (final id in newById.keys) {
      final oldP = oldById[id]!;
      final newP = newById[id]!;
      if (!pointsEqual(oldP.points, newP.points) ||
          oldP.fillColor != newP.fillColor ||
          oldP.strokeWidth != newP.strokeWidth ||
          oldP.strokeColor != newP.strokeColor) {
        _polygons = next;
        widget.onPolygonsChanged(_polygons);
        if (_debug) debugPrint('FOV: update (geometry/style changed) id=$id');
        return;
      }
    }

    // identical => skip
    if (_debug) debugPrint('FOV: skipped (identical)');
  }

  // --- Geodesic helpers ---
  LatLng _computeOffset(LatLng from, double distanceMeters, double bearingDeg) {
    const double R = 6378137.0;
    final double brng = bearingDeg * math.pi / 180.0;
    final double lat1 = from.latitude * math.pi / 180.0;
    final double lon1 = from.longitude * math.pi / 180.0;
    final double dR = distanceMeters / R;

    final double lat2 = math.asin(math.sin(lat1) * math.cos(dR) +
        math.cos(lat1) * math.sin(dR) * math.cos(brng));
    final double lon2 = lon1 +
        math.atan2(math.sin(brng) * math.sin(dR) * math.cos(lat1),
            math.cos(dR) - math.sin(lat1) * math.sin(lat2));

    return LatLng(lat2 * 180.0 / math.pi, lon2 * 180.0 / math.pi);
  }

  List<LatLng> _createSectorPoints(LatLng center, double bearingDeg,
      double halfAngleDeg, double radiusMeters,
      {int steps = 12}) {
    final List<LatLng> pts = [];
    final double start = bearingDeg - halfAngleDeg;
    final double end = bearingDeg + halfAngleDeg;
    pts.add(center);
    for (int i = 0; i <= steps; i++) {
      final double frac = i / steps;
      final double angle = start + (end - start) * frac;
      final LatLng p = _computeOffset(center, radiusMeters, angle);
      pts.add(p);
    }
    pts.add(center);
    return pts;
  }

  double _haversineDistanceMeters(LatLng a, LatLng b) {
    final double R = 6371000.0;
    final double lat1 = a.latitude * math.pi / 180;
    final double lat2 = b.latitude * math.pi / 180;
    final double dLat = lat2 - lat1;
    final double dLon = (b.longitude - a.longitude) * math.pi / 180;
    final double s = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(s), math.sqrt(1 - s));
    return R * c;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
