import 'dart:async';
import 'dart:math';

import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/add_place.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/custom_button.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/map_content.dart';
import 'package:AccessAbility/accessability/presentation/widgets/gpsWidgets/establishment_details_card.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/member_list_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/search_bar.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/service_buttons.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/create_space_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/join_space_widget.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class BottomWidgets extends StatefulWidget {
  final String activeSpaceId;
  final Function(LatLng) onCategorySelected;
  final Function(LatLng, String) onMemberPressed;
  final Place? selectedPlace;
  final VoidCallback? onCloseSelectedPlace;
  final Function(String) fetchNearbyPlaces;
  final Future<void> Function()? onMapViewPressed; // New callback property
  final void Function(Place)? onPlaceSelected; // New callback property
  final ValueChanged<bool>? onSheetExpanded;
  final bool isJoining; // new
  final ValueChanged<bool> onJoinStateChanged; // new

  const BottomWidgets({
    super.key,
    required this.activeSpaceId,
    required this.onCategorySelected,
    required this.onMemberPressed,
    required this.fetchNearbyPlaces,
    this.selectedPlace,
    this.onCloseSelectedPlace,
    this.onMapViewPressed, // Add it here
    this.onPlaceSelected, // Add it here
    this.onSheetExpanded,
    required this.isJoining,
    required this.onJoinStateChanged,
  });

  @override
  _BottomWidgetsState createState() => _BottomWidgetsState();
}

class _BottomWidgetsState extends State<BottomWidgets> {
  final LocationHandler _locationHandler = LocationHandler(
    onMarkersUpdated: (markers) {
      // Handle marker updates if needed
    },
  );
  int _activeIndex = 0; // 0: People, 1: Buildings, 2: Map
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _members = [];
  String? _spaceName;
  String? _verificationCode;
  String? _creatorId;
  String? _selectedMemberId;
  bool _showCreateSpace = false;
  bool _showJoinSpace = false;
  final TextEditingController _spaceNameController = TextEditingController();
  final List<TextEditingController> _verificationCodeControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _verificationCodeFocusNodes =
      List.generate(6, (index) => FocusNode());
  final FlutterTts flutterTts = FlutterTts();
  bool _isLoading = false;
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  StreamSubscription<DocumentSnapshot>? _membersListener;
  final List<StreamSubscription<DocumentSnapshot>> _locationListeners = [];
  bool _isExpanded = false;
  late VoidCallback _sheetListener;
  late final double _expandThreshold = 0.8;
  late final double _collapseThreshold = 0.3;
  @override
  void initState() {
    super.initState();
    _listenToMembers();
    _setupVerificationCodeFocusListeners();
    _initializeLocation();
    _initializeTts();
    _sheetListener = () {
      final extent = _draggableController.size;

      // 1) if you cross 80%, snap to full screen
      if (!_isExpanded && extent >= _expandThreshold) {
        _isExpanded = true;
        widget.onSheetExpanded?.call(true);
        _draggableController.animateTo(1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut);
        return;
      }

      // 2) if you drop below 30%, snap back to collapsed
      if (_isExpanded && extent <= _collapseThreshold) {
        _isExpanded = false;
        widget.onSheetExpanded?.call(false);
        _draggableController.animateTo(
          widget.selectedPlace != null ? 0.6 : 0.3,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    };

    _draggableController.addListener(_sheetListener);
  }

  Future<void> _initializeLocation() async {
    try {
      await _locationHandler.getUserLocation();
      setState(() {}); // Trigger a rebuild after location is fetched
    } catch (e) {
      print("Error fetching user location: $e");
    }
  }

  @override
  void didUpdateWidget(BottomWidgets oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeSpaceId != oldWidget.activeSpaceId) {
      // Set loading state when space ID changes
      setState(() {
        _isLoading = true;
      });
      _listenToMembers(); // Re-fetch members
    }
    // Check for changes in the establishment selection.
    if (oldWidget.selectedPlace == null && widget.selectedPlace != null) {
      // Expand the sheet when an establishment is selected.
      _draggableController.animateTo(
        0.6, // Expanded size (40% of the screen)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (oldWidget.selectedPlace != null &&
        widget.selectedPlace == null) {
      // Collapse the sheet when the establishment is deselected/closed.
      _draggableController.animateTo(
        0.15, // Collapsed size (15% of the screen)
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _draggableController.removeListener(_sheetListener);

    _membersListener?.cancel();
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();
    flutterTts.stop();
    _spaceNameController.dispose();
    for (final controller in _verificationCodeControllers) {
      controller.dispose();
    }
    for (final node in _verificationCodeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _listenToMembers() async {
    if (widget.activeSpaceId.isEmpty) {
      _membersListener?.cancel();
      _membersListener = null;
      _locationListeners.forEach((listener) => listener.cancel());
      _locationListeners.clear();
      setState(() {
        _members = [];
        _spaceName = null;
        _verificationCode = null;
        _isLoading = false; // Reset loading state
      });
      return;
    }

    _membersListener?.cancel();
    _membersListener = null;
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();

    _membersListener = _firestore
        .collection('Spaces')
        .doc(widget.activeSpaceId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        setState(() {
          _members = [];
          _spaceName = null;
          _verificationCode = null;
          _isLoading = false; // Reset loading state
        });
        return;
      }

      final members = snapshot['members'] != null
          ? List<String>.from(snapshot['members'])
          : [];
      final creatorId = snapshot['creator'];
      final spaceName = snapshot['name'] ?? 'Unnamed Space';
      final verificationCode = snapshot['verificationCode'];

      if (members.isEmpty) {
        setState(() {
          _members = [];
          _spaceName = spaceName;
          _verificationCode = verificationCode;
          _creatorId = creatorId;
        });
        return;
      }

      final usersSnapshot = await _firestore
          .collection('Users')
          .where('uid', whereIn: members)
          .get();

      final updatedMembers =
          await Future.wait(usersSnapshot.docs.map((doc) async {
        final locationSnapshot =
            await _firestore.collection('UserLocations').doc(doc['uid']).get();
        final locationData = locationSnapshot.data();
        String address = 'Fetching address...';
        if (locationData != null) {
          final lat = locationData['latitude'];
          final lng = locationData['longitude'];
          address = await _getAddressFromLatLng(LatLng(lat, lng));
        }
        return {
          'uid': doc['uid'],
          'username': doc['username'] ?? 'Unknown',
          'profilePicture': doc['profilePicture'] ??
              'https://firebasestorage.googleapis.com/v0/b/accessability-71ef7.appspot.com/o/profile_pictures%2Fdefault_profile.png?alt=media&token=bc7a75a7-a78e-4460-b816-026a8fc341ba',
          'address': address,
          'lastUpdate': locationData?['timestamp'],
        };
      }));

      setState(() {
        _members = updatedMembers;
        _creatorId = creatorId;
        _spaceName = spaceName;
        _verificationCode = verificationCode;
        _isLoading = false;
      });

      for (final member in members) {
        final listener = _firestore
            .collection('UserLocations')
            .doc(member)
            .snapshots()
            .listen((locationSnapshot) async {
          final locationData = locationSnapshot.data();
          if (locationData != null) {
            final lat = locationData['latitude'];
            final lng = locationData['longitude'];
            final address = await _getAddressFromLatLng(LatLng(lat, lng));
            setState(() {
              final index = _members.indexWhere((m) => m['uid'] == member);
              if (index != -1) {
                _members[index]['address'] = address;
                _members[index]['lastUpdate'] = locationData['timestamp'];
              }
            });
          }
        });
        _locationListeners.add(listener);
      }
    });
  }

  void _setupVerificationCodeFocusListeners() {
    for (int i = 0; i < _verificationCodeControllers.length; i++) {
      _verificationCodeControllers[i].addListener(() {
        if (_verificationCodeControllers[i].text.isNotEmpty && i < 5) {
          FocusScope.of(context)
              .requestFocus(_verificationCodeFocusNodes[i + 1]);
        }
      });
    }
  }

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await flutterTts.speak(text);
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      await _speak("Please enter a location to search.");
      return;
    }

    try {
      final geocodingService = OpenStreetMapGeocodingService();
      final results = await geocodingService.searchLocation(query);

      if (results.isNotEmpty) {
        final firstResult = results.first;
        final address = firstResult.formattedAddress;

        // Announce the result using TTS
        await _speak("Location found: $address");

        // Pan the camera to the searched location
        final location = LatLng(
          firstResult.geometry.location.lat,
          firstResult.geometry.location.lng,
        );
        _locationHandler.panCameraToLocation(location);

        // Update the map to show the location
        widget.onCategorySelected(location);
      } else {
        await _speak(
            "No results found for $query. Please try a different search.");
      }
    } catch (e) {
      await _speak("Error: ${e.toString()}");
    }
  }

  Future<void> _addPerson() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final email = await _showAddPersonDialog();
    if (email == null || email.isEmpty) return;

    if (email == user.email) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You cannot send a verification code to yourself')),
      );
      return;
    }

    final receiverSnapshot = await _firestore
        .collection('Users')
        .where('email', isEqualTo: email)
        .get();

    if (receiverSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found')),
      );
      return;
    }

    final receiverID = receiverSnapshot.docs.first.id;

    final spaceSnapshot =
        await _firestore.collection('Spaces').doc(widget.activeSpaceId).get();

    if (!spaceSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Space not found')),
      );
      return;
    }

    final existingCode = spaceSnapshot['verificationCode'];
    final codeTimestamp = spaceSnapshot['codeTimestamp']?.toDate();

    String verificationCode;
    if (existingCode != null && codeTimestamp != null) {
      final now = DateTime.now();
      final difference = now.difference(codeTimestamp).inMinutes;
      verificationCode =
          difference < 10 ? existingCode : _generateVerificationCode();
    } else {
      verificationCode = _generateVerificationCode();
    }

    final hasChatRoom = await _chatService.hasChatRoom(user.uid, receiverID);
    if (!hasChatRoom) {
      await _chatService.sendChatRequest(
        receiverID,
        'Join My Space! \n Your verification code is: $verificationCode (Expires in 10 minutes)',
      );
    } else {
      await _chatService.sendMessage(
        receiverID,
        'Join My Space! \n Your verification code is: $verificationCode (Expires in 10 minutes)',
      );
    }

    await _firestore.collection('Spaces').doc(widget.activeSpaceId).update({
      'verificationCode': verificationCode,
      'codeTimestamp': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code sent via chat')),
    );
  }

  Future<String?> _showAddPersonDialog() async {
    String? email;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Text(
            'Send Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6750A4),
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Color(0xFF6750A4)), // Outline when not focused
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: Color(0xFF6750A4),
                      width: 2.0), // Outline when focused
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => email = value,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: const Color(0xFF6750A4)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6750A4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    return email;
  }

  Future<void> _createSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final spaceName = _spaceNameController.text;
    if (spaceName.isEmpty) return;

    final verificationCode = _generateVerificationCode();
    final spaceRef = await _firestore.collection('Spaces').add({
      'name': spaceName,
      'creator': user.uid,
      'members': [user.uid],
      'verificationCode': verificationCode,
      'codeTimestamp': DateTime.now(),
      'createdAt': DateTime.now(),
    });

    await _chatService.createSpaceChatRoom(spaceRef.id, spaceName);

    _spaceNameController.clear();
    setState(() {
      _showCreateSpace = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Space created successfully')),
    );
  }

  Future<void> _joinSpace() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final verificationCode = _verificationCodeControllers
        .map((controller) => controller.text)
        .join();
    if (verificationCode.isEmpty) return;

    final snapshot = await _firestore
        .collection('Spaces')
        .where('verificationCode', isEqualTo: verificationCode)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final spaceId = snapshot.docs.first.id;
      final codeTimestamp = snapshot.docs.first['codeTimestamp']?.toDate();

      if (codeTimestamp != null) {
        final now = DateTime.now();
        final difference = now.difference(codeTimestamp).inMinutes;
        if (difference > 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification code has expired')),
          );
          return;
        }
      }

      await _firestore.collection('Spaces').doc(spaceId).update({
        'members': FieldValue.arrayUnion([_auth.currentUser!.uid]),
      });

      await _chatService.addMemberToSpaceChatRoom(
          spaceId, _auth.currentUser!.uid);

      for (final controller in _verificationCodeControllers) {
        controller.clear();
      }
      setState(() {
        _showJoinSpace = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined space successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid verification code')),
      );
    }
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<String> _getAddressFromLatLng(LatLng latLng) async {
    try {
      final geocodingService = OpenStreetMapGeocodingService();
      final address = await geocodingService.getAddressFromLatLng(latLng);
      return address;
    } catch (e) {
      print('Error fetching address: $e');
      return 'Address unavailable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      controller: _draggableController,
      expand: true,
      initialChildSize: widget.isJoining
          ? 1.0 // full‐screen while joining
          : (widget.selectedPlace != null ? 0.6 : 0.30),
      minChildSize: 0.20,
      maxChildSize: 1,
      builder: (context, scrollController) {
        return Column(
          children: [
            IgnorePointer(
              ignoring: _isExpanded || widget.isJoining,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: (_isExpanded || widget.isJoining) ? 0.0 : 1.0,
                child: ServiceButtons(
                  onButtonPressed: (label) {/* … */},
                  currentLocation: _locationHandler.currentLocation,
                  onMapViewPressed: widget.onMapViewPressed,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator()),
                        // --- Default Layout: Always show these ---
                        Container(
                          width: 100,
                          height: 2,
                          color: isDarkMode
                              ? Colors.grey[700]
                              : Colors.grey.shade700,
                          margin: const EdgeInsets.only(bottom: 8),
                        ),
                        const SizedBox(height: 5),
                        SearchBarWithAutocomplete(
                          onSearch: _searchLocation,
                        ),
                        const SizedBox(height: 10),
                        // --- If a place is selected, show only the EstablishmentDetailsCard ---
                        if (widget.selectedPlace != null)
                          EstablishmentDetailsCard(
                            place: widget.selectedPlace!,
                            onClose: widget.onCloseSelectedPlace,
                          )
                        else ...[
                          // Otherwise, show the rest of the UI.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              CustomButton(
                                icon: Icons.people,
                                index: 0,
                                activeIndex: _activeIndex,
                                onPressed: (newIndex) {
                                  // leave join flow
                                  if (widget.isJoining) {
                                    widget.onJoinStateChanged(false);
                                  }
                                  setState(() => _activeIndex = newIndex);
                                },
                              ),
                              CustomButton(
                                icon: Icons.business,
                                index: 1,
                                activeIndex: _activeIndex,
                                onPressed: (int newIndex) {
                                  setState(() {
                                    _activeIndex = newIndex;
                                  });
                                },
                              ),
                              CustomButton(
                                icon: Icons.map,
                                index: 2,
                                activeIndex: _activeIndex,
                                onPressed: (int newIndex) {
                                  setState(() {
                                    _activeIndex = newIndex;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // People Tab: Create/Join Space UI
                          if (_activeIndex == 0 &&
                              widget.activeSpaceId.isEmpty) ...[
                            if (!_showCreateSpace && !_showJoinSpace) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  "mySpace".tr(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.center,
                                child: Text(
                                  "createOrJoinSpace".tr(),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 25),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0), // Add horizontal padding
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Create Space Button
                                    Flexible(
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _showCreateSpace = true;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF6750A4),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 15),
                                          ),
                                          child: Text(
                                            'createSpace'.tr(),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                        width:
                                            10), // Add spacing between buttons
                                    // Join Space Button
                                    Flexible(
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _showJoinSpace = true;
                                            });
                                            widget.onJoinStateChanged(true);
                                            _draggableController.animateTo(
                                              1.0,
                                              duration: const Duration(
                                                  milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF6750A4),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 15),
                                          ),
                                          child: Text(
                                            'joinSpace'.tr(),
                                            style: const TextStyle(
                                                color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_showCreateSpace)
                              CreateSpaceWidget(
                                spaceNameController: _spaceNameController,
                                onCreateSpace: _createSpace,
                                onCancel: () {
                                  setState(() {
                                    _showCreateSpace = false;
                                  });
                                },
                              ),
                            if (_showJoinSpace)
                              JoinSpaceWidget(
                                verificationCodeControllers:
                                    _verificationCodeControllers,
                                verificationCodeFocusNodes:
                                    _verificationCodeFocusNodes,
                                onJoinSpace: _joinSpace,
                                onCodeInput: () {
                                  _draggableController.animateTo(
                                    1.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  widget.onJoinStateChanged(true);
                                },
                                onCancel: () {
                                  setState(() => _showJoinSpace = false);
                                  widget.onJoinStateChanged(false);
                                },
                              ),
                          ],
                          // People Tab: Show MemberListWidget if active space is set.
                          if (_activeIndex == 0 &&
                              widget.activeSpaceId.isNotEmpty)
                            MemberListWidget(
                              members: _members,
                              onMemberPressed: widget.onMemberPressed,
                              selectedMemberId: _selectedMemberId,
                              activeSpaceId: widget.activeSpaceId,
                            ),
                          // People Tab: Show VerificationCodeWidget if current user is creator.
                          if (_creatorId == _auth.currentUser?.uid &&
                              _activeIndex == 0 &&
                              widget.activeSpaceId.isNotEmpty)
                            VerificationCodeWidget(
                              verificationCode: _verificationCode ??
                                  'defaultVerificationCode'.tr(),
                              onSendCode: _addPerson,
                            ),
                          // Business Tab: Show AddPlaceWidget.
                          if (_activeIndex == 1)
                            AddPlaceWidget(
                              onShowPlace: (Place place) {
                                widget.onPlaceSelected?.call(place);
                              },
                            ),
                          // Map Tab: Show MapContent.
                          if (_activeIndex == 2)
                            MapContent(
                              onCategorySelected: (category) {
                                widget.fetchNearbyPlaces(category);
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
