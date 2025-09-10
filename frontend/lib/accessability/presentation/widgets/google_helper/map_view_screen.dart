// lib/presentation/widgets/google_helper/map_perspective_picker.dart
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/map_perspective.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapPerspectivePicker extends StatefulWidget {
  final MapPerspective? initialPerspective;
  final LatLng? currentLocation; // <<< new

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

  final List<_TileSpec> _tiles = [
    _TileSpec(MapPerspective.classic, 'Standard'),
    _TileSpec(MapPerspective.aerial, 'Satellite'),
    _TileSpec(MapPerspective.street, 'Hybrid'),
    _TileSpec(MapPerspective.perspective, '3D'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPerspective = widget.initialPerspective ?? MapPerspective.classic;
    _selectedPerspective = widget.initialPerspective ?? MapPerspective.classic;

    // Use passed in location (if available) instead of creating a new LocationHandler
    if (widget.currentLocation != null) {
      _currentLocation = widget.currentLocation!;
      _isLocationFetched = true;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String? get _apiKey => dotenv.env['GOOGLE_API_KEY'];

  String? _staticMapUrlFor(MapPerspective p) {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    final center = '${_currentLocation.latitude},${_currentLocation.longitude}';
    final mapType = _mapTypeName(p);
    final size = '300x300';
    final zoom = (p == MapPerspective.street || p == MapPerspective.perspective)
        ? '17'
        : '14';
    return 'https://maps.googleapis.com/maps/api/staticmap?center=$center&zoom=$zoom&size=$size&scale=2&maptype=$mapType&key=$_apiKey';
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
        return 'satellite'; // static maps can't tilt — satellite is the closest
      case MapPerspective.classic:
      default:
        return 'roadmap';
    }
  }

  void _onTileTap(MapPerspective p) {
    // Immediately return the choice to caller and close the sheet
    Navigator.of(context)
        .pop({'perspectiveName': p.toString().split('.').last});
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
    final bg = isDarkMode ? Colors.grey[900] : Colors.white;
    final tileBg = isDarkMode ? Colors.grey[850] : Colors.grey[100];

    return SafeArea(
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            const SizedBox(height: 8),
            Container(
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 12),

            // heading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('map_types'.tr(),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            // horizontally scrollable tiles row
            SizedBox(
              height: _tileSize + 36, // tile + label spacing
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
                                child: url != null
                                    ? Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        loadingBuilder: (ctx, child, prog) {
                                          if (prog == null) return child;
                                          return Container(
                                              color: Colors.grey[200]);
                                        },
                                        errorBuilder: (_, __, ___) =>
                                            _placeholderFor(t.perspective),
                                      )
                                    : _placeholderFor(t.perspective),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.label,
                              style: TextStyle(
                                  color: isSelected ? _purple : null,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500),
                            ),
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
}

class _TileSpec {
  final MapPerspective perspective;
  final String label;
  _TileSpec(this.perspective, this.label);
}
