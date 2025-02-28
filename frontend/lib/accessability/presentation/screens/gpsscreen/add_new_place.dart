import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddNewPlaceScreen extends StatefulWidget {
  const AddNewPlaceScreen({super.key});

  @override
  State<AddNewPlaceScreen> createState() => _AddNewPlaceScreenState();
}

class _AddNewPlaceScreenState extends State<AddNewPlaceScreen> {
  // Controller for the place name input
  final TextEditingController _placeNameController = TextEditingController();

  // Google Map controller and location variables
  GoogleMapController? _mapController;
  static const LatLng _initialLocation =
      LatLng(16.04361106008402, 120.33531522527143);
  LatLng _currentLatLng = _initialLocation;

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
          // Row for entering the place name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // TextField for the place name
                    Expanded(
                      child: TextField(
                        controller: _placeNameController,
                        textAlignVertical: TextAlignVertical.bottom,
                        decoration: const InputDecoration(
                          hintText: "Name of place",
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.place,
                            color: Color(0xFF6750A4), // Set the color here
                          ),
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
          // Label for the map location section
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
          // Map with a centered marker (for selecting the place location)
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
                  // Default center marker icon
                  const Center(
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: Color(0xFF6750A4), // Set the color here
                    ),
                  ),
                  // "Next" button at the bottom
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

  // When the user taps "Next", dispatch the add event without a category.
  void _onNextPressed() {
    final placeName = _placeNameController.text.trim();
    if (placeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a place name.")),
      );
      return;
    }

    // Dispatch the AddPlaceEvent with name and location.
    context.read<PlaceBloc>().add(
          AddPlaceEvent(
            name: placeName,
            latitude: _currentLatLng.latitude,
            longitude: _currentLatLng.longitude,
          ),
        );

    // Pop this screen off the stack (go back to the previous screen).
    Navigator.of(context).pop();
  }
}
