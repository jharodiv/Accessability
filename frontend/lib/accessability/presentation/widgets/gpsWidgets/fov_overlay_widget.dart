// fov_overlay_widget.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Simplified FOV overlay with static zoom buckets to avoid heavy work while
/// pinch-zooming. Polygons are rebuilt only when heading/location change
/// significantly or when the zoom *bucket* changes (large / medium / small).
class FovOverlay extends StatefulWidget {
  final LatLng? Function() getCurrentLocation;
  final Stream<LatLng>? locationStream;
  final void Function(Set<Polygon>) onPolygonsChanged;
  final double Function()? getMapZoom;

  final double minZoomToShow;
  final double fovAngle;
  final Color color;
  final int pollIntervalMs;

  // visual tuning (pixel radii used for buckets; converted to meters at bucket-change time)
  final double largeBeamPx;
  final double mediumBeamPx;
  final double smallBeamPx;
  final int steps; // max steps
  final double zoomCutLarge;
  final double zoomCutSmall;

  const FovOverlay({
    Key? key,
    required this.getCurrentLocation,
    required this.onPolygonsChanged,
    this.locationStream,
    this.getMapZoom,
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
  }) : super(key: key);

  @override
  _FovOverlayState createState() => _FovOverlayState();
}

class _FovOverlayState extends State<FovOverlay> {
  StreamSubscription<CompassEvent?>? _compassSub;
  StreamSubscription<LatLng>? _locSub;
  Timer? _pollTimer;
  Timer? _zoomWatchTimer;

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
  double _currentRadiusMeters = 0.0;

  // debug prints toggle
  final bool _debug = false;

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

    // Watch zoom if getter provided (infrequent check)
    if (widget.getMapZoom != null) {
      _zoomWatchTimer =
          Timer.periodic(Duration(milliseconds: 250), (_) => _checkZoom());
      _checkZoom();
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
    super.dispose();
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
        _buildPolygonsForRadius(_currentRadiusMeters);
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
    if (center == null) return;
    final double zoom =
        _lastSeenZoom ?? (widget.zoomCutLarge + widget.zoomCutSmall) / 2.0;
    double px;
    if (bucket == 0) {
      px = widget.largeBeamPx;
    } else if (bucket == 1) {
      px = widget.mediumBeamPx;
    } else {
      px = widget.smallBeamPx;
    }
    final double mpp = _metersPerPixel(center.latitude, zoom);
    final double meters = (px * mpp).clamp(10.0, 350000.0);
    _currentRadiusMeters = meters;
    if (_debug)
      debugPrint(
          'FOV bucket $bucket -> px:$px mpp:${mpp.toStringAsFixed(2)} m:$meters');
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
    _buildPolygonsForRadius(_currentRadiusMeters);
  }

  /// Build polygons for a given radius (meters) and push them to map via callback.
  void _buildPolygonsForRadius(double radiusMeters) {
    final LatLng? userLoc = _lastLocation ?? widget.getCurrentLocation();
    if (userLoc == null) {
      _updatePolygons({});
      return;
    }

    // compute half angle
    final double halfAngle = (widget.fovAngle / 2.0).clamp(1.0, 170.0);

    // shadow (simple offset)
    final double shadowShift = radiusMeters * 0.12;
    final LatLng shadowCenter =
        _computeOffset(userLoc, shadowShift, _heading + 180.0 + 8.0);

    final Set<Polygon> next = {};

    // create shadow polygon (fewer steps)
    final shadowPts = _createSectorPoints(
      shadowCenter,
      _heading,
      halfAngle,
      radiusMeters * 0.95,
      steps: _adaptiveSteps(radiusMeters, userLoc),
    );
    next.add(Polygon(
      polygonId: const PolygonId('fov_shadow'),
      points: shadowPts,
      fillColor: Colors.black.withOpacity(0.14),
      strokeColor: Colors.black.withOpacity(0.06),
      strokeWidth: 0,
      zIndex: 9,
      consumeTapEvents: false,
      geodesic: true,
    ));

    // cone layers: 3 layers using same base radius but smaller multipliers
    final radii = <double>[
      radiusMeters * 0.92,
      radiusMeters * 0.60,
      radiusMeters * 0.30
    ];
    final opacities = <double>[0.36, 0.20, 0.12];
    final zIndices = <int>[13, 12, 11];

    for (int i = 0; i < radii.length; i++) {
      final pts = _createSectorPoints(
        userLoc,
        _heading,
        halfAngle,
        radii[i],
        steps: _adaptiveSteps(radii[i], userLoc),
      );
      next.add(Polygon(
        polygonId: PolygonId('fov_cone_layer_$i'),
        points: pts,
        fillColor: widget.color.withOpacity(opacities[i]),
        strokeColor: widget.color.withOpacity(opacities[i] * 1.2),
        strokeWidth: (i == 0) ? 2 : 1,
        zIndex: zIndices[i],
        consumeTapEvents: false,
        geodesic: true,
      ));
    }

    // highlight (thin)
    final highlightPts = _createSectorPoints(
      userLoc,
      _heading + (widget.fovAngle * 0.04),
      math.max(2.0, widget.fovAngle * 0.06),
      radiusMeters * 0.85,
      steps: _adaptiveSteps(radiusMeters * 0.85, userLoc),
    );
    next.add(Polygon(
      polygonId: const PolygonId('fov_highlight'),
      points: highlightPts,
      fillColor: Colors.white.withOpacity(0.06),
      strokeColor: Colors.white.withOpacity(0.0),
      strokeWidth: 0,
      zIndex: 14,
      consumeTapEvents: false,
      geodesic: true,
    ));

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
    // cap to 6..min(widget.steps,12)
    return raw.clamp(6, widget.steps < 12 ? widget.steps : 12);
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
