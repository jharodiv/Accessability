import 'dart:async';
import 'dart:math';

import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class AddNewPlaceScreen extends StatefulWidget {
  const AddNewPlaceScreen({super.key});

  @override
  State<AddNewPlaceScreen> createState() => _AddNewPlaceScreenState();
}

class _AddNewPlaceScreenState extends State<AddNewPlaceScreen> {
  // Controller for the place name input.
  final TextEditingController _placeNameController = TextEditingController();

  // Google Map controller.
  GoogleMapController? _mapController;

  // Default fallback location.
  LatLng _currentLatLng = const LatLng(16.0430, 120.3333);

  // Instance of LocationHandler (requires onMarkersUpdated).
  late LocationHandler _locationHandler;

  @override
  void initState() {
    super.initState();
    // Initialize LocationHandler with a dummy onMarkersUpdated callback.
    _locationHandler = LocationHandler(
      onMarkersUpdated: (markers) {
        // No marker update logic required in AddNewPlaceScreen.
      },
    );
    // Fetch the current user location.
    _locationHandler.getUserLocation().then((_) {
      print("Fetched location: ${_locationHandler.currentLocation}");
      if (_locationHandler.currentLocation != null) {
        // Initialize user marker (as done in GpsScreen).
        _locationHandler.initializeUserMarker();
        setState(() {
          _currentLatLng = _locationHandler.currentLocation!;
        });
        // If the map is already created, animate the camera.
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _currentLatLng, zoom: 14),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: Text(
          'addNewPlaceTitle'.tr(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Row for entering the place name.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // TextField for the place name.
                    Expanded(
                      child: TextField(
                        controller: _placeNameController,
                        textAlignVertical: TextAlignVertical.bottom,
                        decoration: InputDecoration(
                          hintText: 'nameOfPlace'.tr(),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.place,
                            color: Color(0xFF6750A4),
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
          // Label for the map location section.
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'locateOnMap'.tr(),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Map with a centered marker (for selecting the place location).
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
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // If current location is already fetched, animate the camera.
                      if (_locationHandler.currentLocation != null) {
                        setState(() {
                          _currentLatLng = _locationHandler.currentLocation!;
                        });
                        _mapController!.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(target: _currentLatLng, zoom: 14),
                          ),
                        );
                      }
                    },
                    initialCameraPosition: CameraPosition(
                      target: _currentLatLng,
                      zoom: 14,
                    ),
                    myLocationEnabled: true,
                    onCameraMove: (position) {
                      _currentLatLng = position.target;
                    },
                  ),
                  // Default center marker icon.
                  const Center(
                    child: Icon(
                      Icons.location_on,
                      size: 48,
                      color: Color(0xFF6750A4),
                    ),
                  ),
                  // "Next" button at the bottom.
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
                        child: Text(
                          'next'.tr(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
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

  // When "Next" is pressed, dispatch the AddPlaceEvent with the place name and current location.
  void _onNextPressed() {
    final placeName = _placeNameController.text.trim();
    if (placeName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('enterPlaceName'.tr())),
      );
      return;
    }
    context.read<PlaceBloc>().add(
          AddPlaceEvent(
            name: placeName,
            latitude: _currentLatLng.latitude,
            longitude: _currentLatLng.longitude,
          ),
        );
    Navigator.of(context).pop();
  }
}
