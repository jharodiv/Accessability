import 'dart:async';
import 'dart:math';

import 'package:accessability/accessability/firebaseServices/chat/chat_service.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:accessability/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:accessability/accessability/logic/bloc/user/user_bloc.dart';
import 'package:accessability/accessability/logic/bloc/user/user_state.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:accessability/accessability/presentation/widgets/bottomSheetWidgets/add_place.dart';
import 'package:accessability/accessability/presentation/widgets/bottomSheetWidgets/custom_button.dart';
import 'package:accessability/accessability/presentation/widgets/bottomSheetWidgets/map_content.dart';
import 'package:accessability/accessability/presentation/widgets/gpsWidgets/establishment_details_card.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/member_list_widget.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/searchBar/search_bar.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/service_buttons.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
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
  final Function(String)? onCategorySelectedName; //For String Categories
  final Function(LatLng) onCategorySelected; //it's for Map
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
  final bool isRouteActive;
  final DraggableScrollableController? controller;
  final Future<void> Function()? onShowMyInfoPressed;
  final ValueNotifier<bool>? overlayVisibleNotifier;

  const LocationWidgets({
    super.key,
    required this.activeSpaceId,
    required this.onCategorySelectedName,
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
    required this.isRouteActive, // required now
    this.controller, // <-- add here
    this.onShowMyInfoPressed, // <- add here
    this.overlayVisibleNotifier, // <-- add here
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
  late final DraggableScrollableController _draggableController;
  final double _sheetMinChildSize = 0.30;
  final double _sheetDefaultInitial = 0.35;
  final double _sheetMaxChildSize = 1.0;
  // helper to compute the preferred "normal" initial size
  double get _preferredInitialSize =>
      widget.isJoining ? 1.0 : (widget.selectedPlace != null ? 0.6 : 0.35);

  final TextEditingController _spaceNameController = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  bool _isLoading = false;

  StreamSubscription<DocumentSnapshot>? _membersListener;
  final List<StreamSubscription<DocumentSnapshot>> _locationListeners = [];
  bool _isExpanded = false;
  // late VoidCallback _sheetListener;
  late final double _expandThreshold = 0.8;
  late final double _collapseThreshold = 0.3;
  bool _mapSheetOpening = false;
  VoidCallback? _controllerListener;
  bool _sheetAttached = false;
  double? _pendingAnimateTarget;
  Duration _pendingAnimateDuration = const Duration(milliseconds: 300);
  Curve _pendingAnimateCurve = Curves.easeOut;
  bool _createdControllerLocally = false;
  VoidCallback? _overlayNotifierListener;
  double _serviceAreaFactor = 1.0; // 1.0 = fully visible, 0.0 = hidden
  bool _isAtTop = false; // track if sheet is at the very top (for safe padding)

  //String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[LocationWidgets] initState: activeSpaceId=${widget.activeSpaceId}');

    // Start background init tasks
    _listenToMembers();
    _initializeLocation();
    _initializeTts();

    if (widget.overlayVisibleNotifier != null) {
      _overlayNotifierListener = () {
        try {
          final visible = widget.overlayVisibleNotifier!.value;
          if (visible) {
            // when overlay appears, collapse to min
            _safeAnimateSheetTo(_sheetMinChildSize,
                duration: const Duration(milliseconds: 260));
          } else {
            // optional: when overlay hides, restore preferred size if route not active
            if (!widget.isRouteActive) {
              _safeAnimateSheetTo(_preferredInitialSize,
                  duration: const Duration(milliseconds: 250));
            }
          }
        } catch (e) {
          debugPrint('[LocationWidgets] overlayNotifier listener error: $e');
        }
      };
      widget.overlayVisibleNotifier!.addListener(_overlayNotifierListener!);
    }

    // IMPORTANT: initialize the controller before using it
    if (widget.controller != null) {
      // If the provided controller is already attached to a sheet, don't reuse it:
      try {
        if (widget.controller!.isAttached) {
          debugPrint(
              '[LocationWidgets] passed controller is already attached — creating local controller instead');
          _draggableController = DraggableScrollableController();
          _createdControllerLocally = true;
        } else {
          _draggableController = widget.controller!;
          _createdControllerLocally = false;
        }
      } catch (e, st) {
        // defensive fallback
        debugPrint(
            '[LocationWidgets] error checking passed controller.isAttached: $e\n$st — using local controller');
        _draggableController = DraggableScrollableController();
        _createdControllerLocally = true;
      }
    } else {
      _draggableController = DraggableScrollableController();
      _createdControllerLocally = true;
    }

    // attach a safe listener to update _isExpanded based on controller.size
    _controllerListener = () {
      try {
        final size = _draggableController.size;

        // compute top state (avoid status bar overlap when at very top)
        final bool atTop = size >= 0.995;

        // decide fade start from current preferred initial (dynamic)
        final double _fadeStart = _preferredInitialSize;
        const double _hideThreshold = 0.55;
        const double _factorDirtyThreshold = 0.02;

        // Map size -> factor in a smooth linear ramp between _fadeStart.._hideThreshold
        double factor;
        if (size <= _fadeStart) {
          factor = 1.0;
        } else if (size >= _hideThreshold) {
          factor = 0.0;
        } else {
          factor = 1.0 - (size - _fadeStart) / (_hideThreshold - _fadeStart);
        }
        factor = factor.clamp(0.0, 1.0);

        final bool expanded = size >= _expandThreshold;

        // only update when something meaningful changed to avoid excessive rebuilds
        final bool factorChanged =
            (factor - _serviceAreaFactor).abs() > _factorDirtyThreshold;
        if (factorChanged || atTop != _isAtTop || expanded != _isExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _serviceAreaFactor = factor;
              _isAtTop = atTop;
              _isExpanded = expanded;
            });
          });
        }
      } catch (_) {
        // ignore if controller not ready or removed
      }
    };

    _draggableController.addListener(_controllerListener!);

    // Ensure sheet is at min if a route is already active on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isRouteActive) {
        _safeAnimateSheetTo(_sheetMinChildSize,
            duration: const Duration(milliseconds: 300));
      } else {
        _safeAnimateSheetTo(_preferredInitialSize,
            duration: const Duration(milliseconds: 250));
      }
    });
  }

  Future<void> _safeAnimateSheetTo(double target,
      {Duration duration = const Duration(milliseconds: 300),
      Curve curve = Curves.easeOut}) async {
    if (!mounted) return;

    // If sheet is attached, animate immediately (guarded)
    if (_sheetAttached) {
      try {
        await _draggableController.animateTo(target,
            duration: duration, curve: curve);
      } catch (e, st) {
        debugPrint(
            '[LocationWidgets] animateTo failed (detached mid-call): $e\n$st');
      }
      return;
    }

    // Otherwise queue the animation and it will run when the sheet attaches
    _pendingAnimateTarget = target;
    _pendingAnimateDuration = duration;
    _pendingAnimateCurve = curve;
    debugPrint(
        '[LocationWidgets] queued animateTo($target) — sheet not attached yet');
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
// if the widget was removed while awaiting, bail out
      if (!mounted) return;

// get address
      if (widget.locationHandler.currentLocation != null) {
        final addr = await _getAddressFromLatLng(
            widget.locationHandler.currentLocation!);
        if (!mounted) return;
        setState(() {
          _yourAddress = addr;
        });
      }

// final rebuild
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      print("Error fetching user location: $e");
    }
  }

  @override
  void didUpdateWidget(LocationWidgets oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isRouteActive != widget.isRouteActive) {
      if (widget.isRouteActive) {
        _safeAnimateSheetTo(_sheetMinChildSize,
            duration: const Duration(milliseconds: 300));
      } else {
        _safeAnimateSheetTo(_preferredInitialSize,
            duration: const Duration(milliseconds: 300));
      }
    }

    // Also if selectedPlace or isJoining changed, ensure preferred size adjusts
    if (oldWidget.selectedPlace != widget.selectedPlace ||
        oldWidget.isJoining != widget.isJoining) {
      // only animate back if route not active
      if (!widget.isRouteActive) {
        _safeAnimateSheetTo(_preferredInitialSize,
            duration: const Duration(milliseconds: 250));
      }
    }

    // If the activeSpaceId changed, restart member/location listeners
    if (oldWidget.activeSpaceId != widget.activeSpaceId) {
      // make sure LocationHandler knows about the change too (if you use updateActiveSpaceId)
      try {
        widget.locationHandler.updateActiveSpaceId(widget.activeSpaceId);
      } catch (_) {
        // ignore if handler doesn't have that method, or log if you want
      }

      // Cancel old listeners (safe if null)
      _membersListener?.cancel();
      _membersListener = null;
      _locationListeners.forEach((l) => l.cancel());
      _locationListeners.clear();
      _yourLocationListener?.cancel();
      _yourLocationListener = null;

      // clear local data so UI updates immediately
      setState(() {
        _members = [];
        _spaceName = null;
        _creatorId = null;
        _selectedMemberId = null;
        _isLoading = true;
      });

      // restart listening for the new space
      _listenToMembers();
    }
    if (oldWidget.overlayVisibleNotifier != widget.overlayVisibleNotifier) {
      try {
        if (oldWidget.overlayVisibleNotifier != null &&
            _overlayNotifierListener != null) {
          oldWidget.overlayVisibleNotifier!
              .removeListener(_overlayNotifierListener!);
        }
      } catch (_) {}
      if (widget.overlayVisibleNotifier != null) {
        widget.overlayVisibleNotifier!.addListener(_overlayNotifierListener!);
      }
    }
  }

  @override
  void dispose() {
    // remove controller listener if added

    if (_controllerListener != null) {
      try {
        _draggableController.removeListener(_controllerListener!);
      } catch (_) {}
      _controllerListener = null;
    }

    // cancel all listeners
    _membersListener?.cancel();
    for (final listener in _locationListeners) {
      try {
        listener.cancel();
      } catch (_) {}
    }
    _locationListeners.clear();
    try {
      _yourLocationListener?.cancel();
    } catch (_) {}

    // stop services and dispose controllers you own
    try {
      flutterTts.stop();
    } catch (_) {}

    try {
      _spaceNameController.dispose();
    } catch (_) {}

    // Only dispose the draggable controller if we created it locally
    if (_createdControllerLocally) {
      try {
        _draggableController.dispose();
      } catch (_) {}
    }

    _sheetAttached = false;

    if (_overlayNotifierListener != null) {
      try {
        widget.overlayVisibleNotifier
            ?.removeListener(_overlayNotifierListener!);
      } catch (_) {}
      _overlayNotifierListener = null;
    }
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    try {
      setState(fn);
    } catch (e, st) {
      debugPrint('[LocationWidgets] _safeSetState caught: $e\n$st');
    }
  }

  void _handleMemberPressed(LatLng loc, String uid) {
    setState(() {
      _selectedMemberId = uid;
    });
    widget.onMemberPressed(loc, uid);
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
        if (!mounted) return; // early guard for safety
        final data = snap.data();
        if (data == null) return;

        final lat = data['latitude'];
        final lng = data['longitude'];

        DateTime? ts;
        final rawTs = data['timestamp'];
        if (rawTs is Timestamp) {
          ts = rawTs.toDate();
        } else if (rawTs is int) {
          ts = DateTime.fromMillisecondsSinceEpoch(rawTs);
        }

        String addr;
        try {
          addr = await _getAddressFromLatLng(LatLng(lat, lng));
        } catch (_) {
          addr = 'Unavailable';
        }

        if (!mounted) return;
        setState(() {
          _yourAddress = addr;
          _yourLastUpdate = ts;
        });
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
            // <-- BEFORE setState, ensure mounted
            if (!mounted) return;
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

    // Check if user is already a member of the space
    final spaceSnapshot =
        await _firestore.collection('Spaces').doc(widget.activeSpaceId).get();

    if (!spaceSnapshot.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Space not found')),
      );
      return;
    }

    final currentMembers = List<String>.from(spaceSnapshot['members'] ?? []);

    if (currentMembers.contains(receiverID)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is already a member of this space')),
      );
      return;
    }

    // Use the unified ChatService method
    try {
      await _chatService.sendVerificationCode(
          receiverID, widget.activeSpaceId, _spaceName!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent via chat')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error sending verification code: ${e.toString()}')),
      );
    }
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
      controller: _draggableController,
      expand: true,
      initialChildSize: _preferredInitialSize,
      minChildSize: _sheetMinChildSize,
      maxChildSize: _sheetMaxChildSize,
      builder: (context, scrollController) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_sheetAttached) {
            _sheetAttached = true;
            debugPrint('[LocationWidgets] sheet attached');

            // if there is a pending animation, run it once now
            if (_pendingAnimateTarget != null) {
              final t = _pendingAnimateTarget!;
              final d = _pendingAnimateDuration;
              final c = _pendingAnimateCurve;
              // clear pending before calling to avoid re-entrancy loops
              _pendingAnimateTarget = null;
              Future.microtask(() async {
                if (!mounted) {
                  debugPrint(
                      '[LocationWidgets] skipping pending animate — widget not mounted');
                  return;
                }
                try {
                  await _draggableController.animateTo(t,
                      duration: d, curve: c);
                  debugPrint('[LocationWidgets] applied pending animateTo($t)');
                } catch (e, st) {
                  debugPrint(
                      '[LocationWidgets] pending animate failed: $e\n$st');
                }
              });
            }
          }
        });

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
                // --- SERVICE AREA: copied structure from SafetyAssistWidget ---
                RepaintBoundary(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _serviceAreaFactor,
                      child: Opacity(
                        opacity: _serviceAreaFactor,
                        child: Transform.translate(
                          offset: Offset(0, (1 - _serviceAreaFactor) * 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              // ignore pointer when almost hidden OR route/joining active
                              IgnorePointer(
                                ignoring: _serviceAreaFactor < 0.05 ||
                                    widget.isJoining ||
                                    widget.isRouteActive,
                                child: ServiceButtons(
                                  key: const ValueKey('service_buttons'),
                                  onButtonPressed: (label) {
                                    /* … keep your handler if any */
                                  },
                                  currentLocation:
                                      widget.locationHandler.currentLocation,
                                  onMapViewPressed: () async {
                                    if (_mapSheetOpening) {
                                      debugPrint(
                                          '[LocationWidgets] map sheet already opening - ignoring tap');
                                      return;
                                    }
                                    _mapSheetOpening = true;
                                    try {
                                      debugPrint(
                                          '[LocationWidgets] onMapViewPressed wrapper fired.');
                                      await widget.onMapViewPressed?.call();
                                    } finally {
                                      await Future.delayed(
                                          const Duration(milliseconds: 200));
                                      _mapSheetOpening = false;
                                    }
                                  },
                                  onCenterPressed: () async {
                                    debugPrint(
                                        'GPS button pressed (center/reset)');
                                    final currentLoc =
                                        widget.locationHandler.currentLocation;
                                    if (currentLoc == null) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'locationNotAvailable'.tr())),
                                      );
                                      return;
                                    }

                                    // mark local selection so UI highlights "You"
                                    final id = _auth.currentUser?.uid;
                                    if (id != null) {
                                      setState(() {
                                        _selectedMemberId = id;
                                      });
                                    }

                                    // collapse sheet to min first so the overlay will position correctly
                                    try {
                                      await _safeAnimateSheetTo(
                                        _sheetMinChildSize,
                                        duration:
                                            const Duration(milliseconds: 260),
                                      );
                                    } catch (e, st) {
                                      debugPrint(
                                          '[LocationWidgets] safeAnimateSheetTo failed: $e\n$st');
                                    }

                                    // pan camera to current location
                                    try {
                                      widget.locationHandler
                                          .panCameraToLocation(currentLoc);
                                    } catch (e, st) {
                                      debugPrint(
                                          'panCameraToLocation threw: $e\n$st');
                                    }

                                    // then ask the host (GpsScreen) to show the "my info" overlay
                                    if (widget.onShowMyInfoPressed != null) {
                                      try {
                                        await widget.onShowMyInfoPressed!
                                            .call();
                                      } catch (e, st) {
                                        debugPrint(
                                            '[LocationWidgets] onShowMyInfoPressed threw: $e\n$st');
                                        // fallback: call the older onMemberPressed behavior if provided
                                        if (id != null) {
                                          widget.onMemberPressed(
                                              currentLoc, id);
                                        }
                                      }
                                    } else {
                                      // fallback if no host handler provided
                                      if (id != null) {
                                        widget.onMemberPressed(currentLoc, id);
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        top: _isAtTop ? MediaQuery.of(context).padding.top : 0),
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
                            blurRadius: 0.5, // soft edge
                            offset: Offset(-1, 0), // left side
                          ),
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 0.5,
                            offset: Offset(1, 0), // right side
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
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                              ),
                              const SizedBox(height: 5),
                              SearchBarWithAutocomplete(
                                onSearch: _searchLocation,
                                onCategorySelected: (category) {
                                  print(
                                      "Parent Callback triggered with: $category");
                                  widget.onCategorySelectedName?.call(category);
                                },
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
                                            backgroundImage: profilePicture !=
                                                        null &&
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
                                          onTap: () async {
                                            final id = _auth.currentUser?.uid;
                                            if (id != null) {
                                              setState(() {
                                                _selectedMemberId = id;
                                              });
                                            }

                                            // collapse sheet first
                                            try {
                                              await _safeAnimateSheetTo(
                                                  _sheetMinChildSize,
                                                  duration: const Duration(
                                                      milliseconds: 260));
                                            } catch (e, st) {
                                              debugPrint(
                                                  '[LocationWidgets] safeAnimateSheetTo failed: $e\n$st');
                                            }

                                            // call host overlay handler
                                            if (widget.onShowMyInfoPressed !=
                                                null) {
                                              try {
                                                await widget
                                                    .onShowMyInfoPressed!
                                                    .call();
                                              } catch (e, st) {
                                                debugPrint(
                                                    '[LocationWidgets] onShowMyInfoPressed threw: $e\n$st');
                                                // fallback to existing behavior if desired
                                                if (widget.locationHandler
                                                        .currentLocation !=
                                                    null) {
                                                  widget.onMemberPressed(
                                                      widget.locationHandler
                                                          .currentLocation!,
                                                      _auth.currentUser!.uid);
                                                }
                                              }
                                              return;
                                            }

                                            // fallback existing behavior
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
                                            onTap: () {
                                              // Open create-space flow (same as space sheet)
                                              Navigator.pushNamed(
                                                      context, '/createSpace')
                                                  .then((success) {
                                                if (success == true) {
                                                  // If you have logic to refresh spaces or members, call it here.
                                                  // For example: _listenToMembers(); // optional
                                                }
                                              });
                                            },
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor:
                                                      const Color(0xFF6750A4)
                                                          .withOpacity(0.2),
                                                  child: Icon(Icons.add,
                                                      size: 26,
                                                      color: const Color(
                                                          0xFF6750A4)),
                                                ),
                                                const SizedBox(width: 12),
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
                                      yourLocation: widget
                                          .locationHandler.currentLocation,
                                      yourAddressLabel:
                                          _yourAddress ?? 'Current Location',
                                      yourLastUpdate: _yourLastUpdate,
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
                                      onShowMyInfoPressed: () async {
                                        final uid = FirebaseAuth
                                            .instance.currentUser?.uid;
                                        if (uid != null) {
                                          setState(() {
                                            _selectedMemberId = uid;
                                          });
                                        }

                                        // collapse sheet to min immediately (or queued if detached)
                                        try {
                                          await _safeAnimateSheetTo(
                                              _sheetMinChildSize,
                                              duration: const Duration(
                                                  milliseconds: 260));
                                        } catch (e, st) {
                                          debugPrint(
                                              '[LocationWidgets] safeAnimateSheetTo failed: $e\n$st');
                                        }

                                        // then call the host-provided handler (GpsScreen) that shows the overlay
                                        if (widget.onShowMyInfoPressed !=
                                            null) {
                                          try {
                                            await widget.onShowMyInfoPressed!
                                                .call();
                                          } catch (e, st) {
                                            debugPrint(
                                                '[LocationWidgets] host onShowMyInfoPressed threw: $e\n$st');
                                          }
                                        }
                                      },
                                      isLoading: _isLoading,
                                      onMemberPressed:
                                          (LatLng loc, String uid) async {
                                        // update local selection so the list highlights the tapped member
                                        setState(() {
                                          _selectedMemberId = uid;
                                        });

                                        // collapse sheet to min so overlay will position correctly
                                        try {
                                          await _safeAnimateSheetTo(
                                              _sheetMinChildSize,
                                              duration: const Duration(
                                                  milliseconds: 260));
                                        } catch (e, st) {
                                          debugPrint(
                                              '[LocationWidgets] safeAnimateSheetTo failed: $e\n$st');
                                        }

                                        // forward to GpsScreen (or whatever parent handler) to show overlay / pan camera
                                        widget.onMemberPressed(loc, uid);
                                      },
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
                                  MapContent(),
                              ],
                            ],
                          ),
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
