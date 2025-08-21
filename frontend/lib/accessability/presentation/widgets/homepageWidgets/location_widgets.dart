import 'dart:async';
import 'dart:math';

import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/data/model/place.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/user/user_state.dart';
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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';

class LocationWidgets extends StatefulWidget {
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
  final LocationHandler locationHandler;

  const LocationWidgets({
    super.key,
    required this.activeSpaceId,
    required this.onCategorySelected,
    required this.onMemberPressed,
    required this.fetchNearbyPlaces,
    required this.locationHandler,
    this.selectedPlace,
    this.onCloseSelectedPlace,
    this.onMapViewPressed, // Add it here
    this.onPlaceSelected, // Add it here
    this.onSheetExpanded,
    required this.isJoining,
    required this.onJoinStateChanged,
  });

  @override
  _LocationWidgetsState createState() => _LocationWidgetsState();
}

class _LocationWidgetsState extends State<LocationWidgets> {
  int _activeIndex = 0; // 0: People, 1: Buildings, 2: Map
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _members = [];
  String? _spaceName;
  String? _creatorId;
  String? _selectedMemberId;
  String? _yourAddress;
  DateTime? _yourLastUpdate;
  StreamSubscription<DocumentSnapshot>? _yourLocationListener;

  final TextEditingController _spaceNameController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  bool _isLoading = false;
  // final DraggableScrollableController _draggableController =
  //     DraggableScrollableController();

  StreamSubscription<DocumentSnapshot>? _membersListener;
  final List<StreamSubscription<DocumentSnapshot>> _locationListeners = [];
  bool _isExpanded = false;
  // late VoidCallback _sheetListener;
  late final double _expandThreshold = 0.8;
  late final double _collapseThreshold = 0.3;
  @override
  void initState() {
    super.initState();
    _listenToMembers();
    _initializeLocation();
    _initializeTts();
  }

  String _timeDiff(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays}d';
  }

  Future<void> _initializeLocation() async {
    try {
      await widget.locationHandler.getUserLocation();
      // get the human readable address for current location (if available)
      if (widget.locationHandler.currentLocation != null) {
        final addr = await _getAddressFromLatLng(
            widget.locationHandler.currentLocation!);
        setState(() {
          _yourAddress = addr;
        });
      }
      setState(() {}); // Trigger a rebuild after location + address is fetched
    } catch (e) {
      print("Error fetching user location: $e");
    }
  }

  @override
  void didUpdateWidget(LocationWidgets oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    // _draggableController.removeListener(_sheetListener);

    _membersListener?.cancel();
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();
    _yourLocationListener?.cancel();

    flutterTts.stop();
    _spaceNameController.dispose();
    super.dispose();
  }

  void _listenToMembers() async {
    // cancel previous listeners
    setState(() => _isLoading = true);

    _membersListener?.cancel();
    _membersListener = null;
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();
    _yourLocationListener?.cancel();

    // --- ALWAYS listen to current user's UserLocations doc ---
    final currentUid = _auth.currentUser?.uid;
    if (currentUid != null) {
      _yourLocationListener = _firestore
          .collection('UserLocations')
          .doc(currentUid)
          .snapshots()
          .listen((snap) async {
        final data = snap.data();
        if (data != null) {
          final lat = data['latitude'];
          final lng = data['longitude'];

          // convert timestamp safely
          DateTime? ts;
          final rawTs = data['timestamp'];
          if (rawTs is Timestamp)
            ts = rawTs.toDate();
          else if (rawTs is int)
            ts = DateTime.fromMillisecondsSinceEpoch(rawTs);

          // fetch readable address (optional but consistent with members)
          String addr;
          try {
            addr = await _getAddressFromLatLng(LatLng(lat, lng));
          } catch (_) {
            addr = 'Unavailable';
          }

          setState(() {
            _yourAddress = addr;
            _yourLastUpdate = ts;
          });
        }
      });

      // add to _locationListeners so it's canceled along with others if needed
      _locationListeners.add(_yourLocationListener!);
    }

    // If no active space, clear member list and return
    if (widget.activeSpaceId.isEmpty) {
      setState(() {
        _members = [];
        _spaceName = null;
        _isLoading = false;
      });
      return;
    }

    // --- existing members listener logic (unchanged) ---
    _membersListener = _firestore
        .collection('Spaces')
        .doc(widget.activeSpaceId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        setState(() {
          _members = [];
          _spaceName = null;
          _isLoading = false;
        });
        return;
      }

      final raw = snapshot.data()?['members'];
      final members = <String>[];
      if (raw is List && raw.isNotEmpty) {
        members.addAll(List<String>.from(raw));
      }

      final creatorId = snapshot['creator'];
      final spaceName = snapshot['name'] ?? 'Unnamed Space';
      final verificationCode = snapshot['verificationCode'];

      if (members.isEmpty) {
        setState(() {
          _members = [];
          _spaceName = spaceName;
          _creatorId = creatorId;
          _isLoading = false;
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
          // prefer separate fields, but keep 'username' for compatibility:
          'firstName': (doc['firstName'] ?? '').toString(),
          'lastName': (doc['lastName'] ?? '').toString(),
          // create a combined full name and also put it into 'username' to avoid breaking callers
          'username': ('${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}')
                  .toString()
                  .trim()
                  .isNotEmpty
              ? ('${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}')
                  .toString()
                  .trim()
              : (doc['username'] ?? 'Unknown'),
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
        _isLoading = false;
      });

      // set up per-member listeners
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
        await widget.locationHandler.panCameraToLocation(location);

        // Update the map to show the location (if parent wants it)
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
          content: Text('You cannot send a verification code to yourself'),
        ),
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

    // Get or generate verification code
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

    // Update space with new verification code and timestamp
    await _firestore.collection('Spaces').doc(widget.activeSpaceId).update({
      'verificationCode': verificationCode,
      'codeTimestamp': DateTime.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Verification code sent via chat')),
    );
  }

  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
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

  void _resetCameraToNormal() {
    final loc = widget.locationHandler.currentLocation;
    if (loc != null) {
      widget.locationHandler.panCameraToLocation(loc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      // controller: _draggableController,
      expand: true,
      initialChildSize: widget.isJoining
          ? 1.0 // full‐screen while joining
          : (widget.selectedPlace != null ? 0.6 : 0.30),
      minChildSize: 0.20,
      maxChildSize: 1,
      builder: (context, scrollController) {
        return BlocBuilder<UserBloc, UserState>(
          builder: (context, userState) {
            final currentUser = _auth.currentUser;

            // Get username from UserBloc instead of Firebase Auth directly
            String userName;
            String? profilePicture;
            String avatarLetter;

            if (userState is UserLoaded) {
              final firstName = (userState.user.firstName ?? '').trim();
              final lastName = (userState.user.lastName ?? '').trim();
              if (firstName.isNotEmpty || lastName.isNotEmpty) {
                userName =
                    '${firstName}${firstName.isNotEmpty && lastName.isNotEmpty ? ' ' : ''}$lastName'
                        .trim();
              } else {
                // fallback to existing username field if no first/last provided
                userName = (userState.user.username ?? 'User').trim();
              }
              profilePicture = userState.user.profilePicture;
              // avatar letter use first name if available, else fallback to first char of userName
              final avatarSource =
                  (userState.user.firstName ?? '').trim().isNotEmpty
                      ? userState.user.firstName!.trim()
                      : userName;
              avatarLetter =
                  avatarSource.isNotEmpty ? avatarSource[0].toUpperCase() : 'U';
            } else {
              // Fallback to Firebase Auth data
              String display = (currentUser?.displayName?.trim() ?? '');
              if (display.isNotEmpty) {
                // try to split displayName into first + last
                final parts = display.split(RegExp(r'\s+'));
                final first = parts.isNotEmpty ? parts.first : '';
                final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                userName =
                    '${first}${first.isNotEmpty && last.isNotEmpty ? ' ' : ''}$last'
                        .trim();
                avatarLetter = first.isNotEmpty
                    ? first[0].toUpperCase()
                    : (userName.isNotEmpty ? userName[0].toUpperCase() : 'U');
              } else {
                // finally fallback to email prefix
                userName = (currentUser?.email?.split('@').first ?? 'User');
                avatarLetter =
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
              }
              profilePicture = currentUser?.photoURL;
            }
            return Column(
              children: [
                IgnorePointer(
                  ignoring: _isExpanded || widget.isJoining,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: (_isExpanded || widget.isJoining) ? 0.0 : 1.0,
                    child: ServiceButtons(
                      onButtonPressed: (label) {/* … */},
                      currentLocation: widget.locationHandler.currentLocation,
                      onMapViewPressed: widget.onMapViewPressed,
                      onCenterPressed: () {
                        debugPrint('GPS button pressed');
                        debugPrint(
                            'locationHandler.currentLocation: ${widget.locationHandler.currentLocation}');
                        if (widget.locationHandler.currentLocation == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('locationNotAvailable'.tr())),
                          );
                          return;
                        }
                        try {
                          widget.locationHandler.panCameraToLocation(
                              widget.locationHandler.currentLocation!);
                          debugPrint('Called panCameraToLocation()');
                        } catch (e, st) {
                          debugPrint('panCameraToLocation threw: $e\n$st');
                        }
                      },
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
                          blurRadius: 5,
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
                              BlocProvider.value(
                                value: BlocProvider.of<UserBloc>(context),
                                child: EstablishmentDetailsCard(
                                  place: widget.selectedPlace!,
                                  onClose: widget.onCloseSelectedPlace,
                                  isPwdLocation:
                                      widget.selectedPlace!.category ==
                                          'PWD Friendly',
                                ),
                              )
                            else ...[
                              // Otherwise, show the rest of the UI.
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                              if (_activeIndex == 0) ...[
                                if (widget.activeSpaceId.isEmpty)
                                  // No space selected: user-card + button
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 1) Current user row (same as MemberListWidget)
                                      ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage:
                                              profilePicture != null &&
                                                      profilePicture.isNotEmpty
                                                  ? NetworkImage(profilePicture)
                                                  : null,
                                          child: profilePicture == null ||
                                                  profilePicture.isEmpty
                                              ? Text(avatarLetter,
                                                  style: const TextStyle(
                                                      color: Colors.white))
                                              : null,
                                        ),
                                        title: Text(
                                          userName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _yourAddress ??
                                                  'Current Location',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Updated: ${_yourLastUpdate != null ? _timeDiff(_yourLastUpdate!) : 'just now'}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          if (widget.locationHandler
                                                  .currentLocation !=
                                              null) {
                                            widget.onMemberPressed(
                                                widget.locationHandler
                                                    .currentLocation!,
                                                _auth.currentUser!.uid);
                                          }
                                        },
                                      ),

                                      // small spacing + divider (same visual separation used in MemberListWidget)
                                      const SizedBox(height: 8),
                                      Divider(
                                          color: isDarkMode
                                              ? Colors.grey[700]
                                              : Colors.grey[300]),

                                      // 2) Create-circle CTA aligned with avatar (left)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12.0, horizontal: 16.0),
                                        child: InkWell(
                                          // onTap:
                                          //     _createCircleAuto, // creates a circle immediately (no dialog)
                                          child: Row(
                                            children: [
                                              // left: circular button (aligned like avatar)
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor: const Color(
                                                        0xFF6750A4)
                                                    // ignore: deprecated_member_use
                                                    .withOpacity(0.2),
                                                child: Icon(Icons.add,
                                                    size: 26,
                                                    color: const Color(
                                                        0xFF6750A4)),
                                              ),

                                              const SizedBox(width: 12),

                                              // right: CTA text
                                              const Text(
                                                'Create a circle',
                                                style: TextStyle(
                                                  color: Color(0xFF6750A4),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else ...[
                                  // Space selected: show members
                                  MemberListWidget(
                                    activeSpaceId: widget.activeSpaceId,
                                    members: _members,
                                    selectedMemberId: _selectedMemberId,
                                    yourLocation:
                                        widget.locationHandler.currentLocation,
                                    yourAddressLabel:
                                        _yourAddress ?? 'Current Location',
                                    yourLastUpdate: _yourLastUpdate,
                                    onMemberPressed: widget.onMemberPressed,
                                    onAddPerson: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              VerificationCodeScreen(
                                            spaceId: widget.activeSpaceId,
                                            spaceName: _spaceName,
                                          ),
                                        ),
                                      );
                                    },
                                    isLoading: _isLoading,
                                  ),
                                ],
                              ] else if (_activeIndex == 1) ...[
                                AddPlaceWidget(
                                  onShowPlace: (Place place) {
                                    widget.onPlaceSelected?.call(place);
                                  },
                                ),
                                // Map Tab: Show MapContent.
                              ] else if (_activeIndex == 2)
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
      },
    );
  }
}
