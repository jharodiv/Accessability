import 'package:flutter/material.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_event.dart';

enum PlaceCategory {
  favorite,
  wantToGo,
  visited,
}

class AddNewPlaceScreen extends StatefulWidget {
  const AddNewPlaceScreen({Key? key}) : super(key: key);

  @override
  State<AddNewPlaceScreen> createState() => _AddNewPlaceScreenState();
}

class _AddNewPlaceScreenState extends State<AddNewPlaceScreen> {
  // Controllers
  final TextEditingController _placeNameController = TextEditingController();

  // Google Map
  GoogleMapController? _mapController;
  static const LatLng _initialLocation =
      LatLng(16.04361106008402, 120.33531522527143);
  LatLng _currentLatLng = _initialLocation;

  // Category selection
  PlaceCategory _selectedCategory = PlaceCategory.favorite;

  // Map category to icons
  final Map<PlaceCategory, IconData> categoryIcons = {
    PlaceCategory.favorite: Icons.favorite,
    PlaceCategory.wantToGo: Icons.flag,
    PlaceCategory.visited: Icons.check_circle,
  };

  // Map category to labels (for popup menu)
  final Map<PlaceCategory, String> categoryLabels = {
    PlaceCategory.favorite: "Favorite",
    PlaceCategory.wantToGo: "Want to Go",
    PlaceCategory.visited: "Visited",
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "Add a new Place",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // "Search bar" / place name row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    // PopupMenu for category selection
                    PopupMenuButton<PlaceCategory>(
                      onSelected: (PlaceCategory value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                      icon: Icon(
                        categoryIcons[_selectedCategory],
                        color: const Color(0xFF6750A4),
                      ),
                      itemBuilder: (BuildContext context) {
                        return PlaceCategory.values.map((category) {
                          return PopupMenuItem<PlaceCategory>(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  categoryIcons[category],
                                  color: const Color(0xFF6750A4),
                                ),
                                const SizedBox(width: 8),
                                Text(categoryLabels[category]!),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                    const SizedBox(width: 3),
                    // TextField for place name
                    Expanded(
                      child: TextField(
                        controller: _placeNameController,
                        decoration: const InputDecoration(
                          hintText: "Name of place",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(
                  thickness: 1,
                  height: 1,
                  color: Colors.grey,
                ),
              ],
            ),
          ),

          // "Locate on Map" label
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Locate on Map",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // The map with the pinned marker
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (controller) => _mapController = controller,
                    initialCameraPosition: const CameraPosition(
                      target: _initialLocation,
                      zoom: 14,
                    ),
                    onCameraMove: (position) {
                      _currentLatLng = position.target;
                    },
                  ),
                  // Center marker that changes with category
                  Center(
                    child: Icon(
                      categoryIcons[_selectedCategory],
                      size: 48,
                      color: const Color(0xFF6750A4),
                    ),
                  ),
                  // "Next" button pinned at the bottom
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6750A4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _onNextPressed,
                        child: const Text(
                          "Next",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onNextPressed() {
    final placeName = _placeNameController.text.trim();
    if (placeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a place name.")),
      );
      return;
    }

    // Dispatch the AddPlaceEvent with all details
    context.read<UserBloc>().add(
          AddPlaceEvent(
            name: placeName,
            category: categoryLabels[_selectedCategory]!,
            latitude: _currentLatLng.latitude,
            longitude: _currentLatLng.longitude,
          ),
        );

    // Navigate back to the home screen ("/") after adding the place
    Navigator.of(context).pushNamedAndRemoveUntil("/", (route) => false);
  }
}
