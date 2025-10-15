// lib/presentation/widgets/google_helper/map_perspective_picker.dart
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/map_perspective.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapPerspectivePicker extends StatefulWidget {
  final MapPerspective? initialPerspective;
  final LatLng? currentLocation;

  const MapPerspectivePicker(
      {Key? key, this.initialPerspective, this.currentLocation})
      : super(key: key);

  @override
  _MapPerspectivePickerState createState() => _MapPerspectivePickerState();
}

class _MapPerspectivePickerState extends State<MapPerspectivePicker> {
  late MapPerspective _selectedPerspective;
  LatLng _currentLocation = const LatLng(16.0430, 120.3333);
  bool _isLocationFetched = false;

  static const double _tileSize = 92.0;
  static const Color _purple = Color(0xFF6750A4);

  // preference key
  static const String _prefsKey = 'last_map_perspective';

  final List<_TileSpec> _tiles = [
    _TileSpec(MapPerspective.classic, 'Standard'),
    _TileSpec(MapPerspective.aerial, 'Satellite'),
    _TileSpec(MapPerspective.street, 'Hybrid'),
    _TileSpec(MapPerspective.perspective, '3D'),
  ];

  @override
  void initState() {
    super.initState();

    // If parent provided a forced initial perspective, prefer it.
    _selectedPerspective = widget.initialPerspective ?? MapPerspective.classic;

    // Use passed-in location if provided
    if (widget.currentLocation != null) {
      _currentLocation = widget.currentLocation!;
      _isLocationFetched = true;
    }

    // load saved preference (only if parent didn't provide an explicit initialPerspective)
    if (widget.initialPerspective == null) {
      _loadSavedPerspective();
    }
  }

  @override
  void didUpdateWidget(covariant MapPerspectivePicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If parent changed the initialPerspective, update selection accordingly
    if (widget.initialPerspective != null &&
        widget.initialPerspective != oldWidget.initialPerspective &&
        widget.initialPerspective != _selectedPerspective) {
      setState(() {
        _selectedPerspective = widget.initialPerspective!;
      });
    }

    // If the parent passes/updates currentLocation later, reflect it so perspective tile can render.
    if (widget.currentLocation != oldWidget.currentLocation) {
      if (widget.currentLocation != null) {
        setState(() {
          _currentLocation = widget.currentLocation!;
          _isLocationFetched = true;
        });
      } else {
        setState(() {
          _isLocationFetched = false;
        });
      }
    }
  }

  Future<void> _loadSavedPerspective() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        final parsed = _parsePerspective(saved);
        if (parsed != null) {
          setState(() {
            _selectedPerspective = parsed;
          });
        }
      }
    } catch (e) {
      // ignore failure to read prefs
    }
  }

  Future<void> _savePerspective(MapPerspective p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _perspectiveToKey(p));
    } catch (e) {
      // ignore saving errors
    }
  }

  String? get _apiKey => dotenv.env['GOOGLE_API_KEY'];

  String _perspectiveToKey(MapPerspective p) => p.toString().split('.').last;

  MapPerspective? _parsePerspective(String key) {
    for (final v in MapPerspective.values) {
      if (v.toString().split('.').last.toLowerCase() == key.toLowerCase()) {
        return v;
      }
    }
    return null;
  }

  /// Build a Static Maps URL for the given perspective.
  /// Note: Static Maps can't be tilted; we use satellite/hybrid appropriately.
  String? _staticMapUrlFor(MapPerspective p) {
    if (_apiKey == null || _apiKey!.isEmpty) return null;

    final center = '${_currentLocation.latitude},${_currentLocation.longitude}';
    final mapType = _mapTypeName(p);
    final int sizePx =
        (_tileSize.toInt() * 2); // produce higher source resolution
    final zoom = _zoomFor(p);
    final marker = 'color:red%7C$center';
    return 'https://maps.googleapis.com/maps/api/staticmap'
        '?center=$center&zoom=$zoom&size=${sizePx}x${sizePx}&scale=1'
        '&maptype=$mapType&markers=$marker&key=$_apiKey';
  }

  int _zoomFor(MapPerspective p) {
    switch (p) {
      case MapPerspective.aerial:
        return 16;
      case MapPerspective.street:
        return 17;
      case MapPerspective.perspective:
        return 17;
      case MapPerspective.classic:
      default:
        return 14;
    }
  }

  String _mapTypeName(MapPerspective p) {
    switch (p) {
      case MapPerspective.aerial:
        return 'satellite';
      case MapPerspective.terrain:
        return 'terrain';
      case MapPerspective.street:
        return 'hybrid';
      case MapPerspective.perspective:
        return 'satellite';
      case MapPerspective.classic:
      default:
        return 'roadmap';
    }
  }

  /// When a tile is tapped: update state (so highlight shows), save to prefs and return to parent.
  /// We return both a string name and an index so parent parsing is robust.
  void _onTileTap(MapPerspective p) async {
    setState(() => _selectedPerspective = p);
    await _savePerspective(p);

    Navigator.of(context).pop({
      'perspectiveName': _perspectiveToKey(p),
      'perspectiveIndex': MapPerspective.values.indexOf(p),
    });
  }

  Widget _placeholderFor(MapPerspective p) {
    switch (p) {
      case MapPerspective.aerial:
        return Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.green[300]!, Colors.green[100]!])));

      case MapPerspective.street:
        return Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.blueGrey[300]!, Colors.blueGrey[100]!])));

      case MapPerspective.perspective:
        return Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
          Colors.deepPurple[300]!,
          Colors.deepPurple[100]!
        ])));

      case MapPerspective.classic:
      default:
        return Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.orange[200]!, Colors.orange[50]!])));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final tileBg = isDarkMode ? Colors.grey[850] : Colors.grey[100];

    return SafeArea(
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // draggable visual handle (so sheet feels draggable)
            const SizedBox(height: 12),

            // TOP ROW: plain X (no background) on left + title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // plain X button (no background)
                  Semantics(
                    label: 'Close Button',
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(Icons.close, size: 20, color: _purple),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Title
                  Expanded(
                    child: Text(
                      'map_types'.tr(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: _tileSize + 36,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _tiles.map((t) {
                    final isSelected = _selectedPerspective == t.perspective;
                    final url = _staticMapUrlFor(t.perspective);
                    return Padding(
                      padding: const EdgeInsets.only(right: 14.0),
                      child: GestureDetector(
                        onTap: () => _onTileTap(t.perspective),
                        child: Column(
                          children: [
                            // tile box with highlight overlay when selected
                            Container(
                              width: _tileSize,
                              height: _tileSize,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _purple.withOpacity(0.07)
                                    : tileBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isSelected
                                        ? _purple
                                        : Colors.transparent,
                                    width: isSelected ? 3 : 0),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 3))
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildTileContent(t.perspective, url),
                                    if (isSelected)
                                      Container(
                                        color: _purple.withOpacity(0.06),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(t.label,
                                style: TextStyle(
                                    color: isSelected ? _purple : null,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Build the content for a tile. For "perspective" we use a small interactive GoogleMap
  /// if we have a current location and the platform supports it. Otherwise we use static image or placeholder.
  Widget _buildTileContent(MapPerspective p, String? url) {
    // 1) If this is the perspective (3D) tile — try to show a small interactive GoogleMap (so tilt is visible).
    if (p == MapPerspective.perspective && _isLocationFetched) {
      final CameraPosition camera = CameraPosition(
          target: _currentLocation,
          zoom: _zoomFor(p).toDouble(),
          tilt: 45,
          bearing: 30);
      return AbsorbPointer(
        // disable gestures so it behaves like an image
        child: GoogleMap(
          initialCameraPosition: camera,
          mapType: MapType.satellite,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: false,
          scrollGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          trafficEnabled: false,
          buildingsEnabled: true,
          liteModeEnabled: false,
          onMapCreated: (_) {},
        ),
      );
    }

    // 2) Otherwise use static image if url is available
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (ctx, child, prog) {
          if (prog == null) return child;
          return Container(color: Colors.grey[200]);
        },
        errorBuilder: (_, __, ___) => _placeholderFor(p),
      );
    }

    // 3) fallback placeholder
    return _placeholderFor(p);
  }
}

class _TileSpec {
  final MapPerspective perspective;
  final String label;
  _TileSpec(this.perspective, this.label);
}
