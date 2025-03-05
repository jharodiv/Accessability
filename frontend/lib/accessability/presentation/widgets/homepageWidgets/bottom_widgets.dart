import 'dart:async';
import 'dart:math';

import 'package:AccessAbility/accessability/firebaseServices/chat/chat_service.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/add_place.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/custom_button.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/map_content.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/member_list_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/service_buttons.dart';
import 'package:AccessAbility/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/create_space_widget.dart';
import 'package:AccessAbility/accessability/presentation/widgets/bottomSheetWidgets/join_space_widget.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BottomWidgets extends StatefulWidget {
  final ScrollController scrollController;
  final String activeSpaceId;
  final Function(String) onCategorySelected;
  final Function(LatLng, String) onMemberPressed;

  const BottomWidgets({
    super.key,
    required this.scrollController,
    required this.activeSpaceId,
    required this.onCategorySelected,
    required this.onMemberPressed,
  });

  @override
  _BottomWidgetsState createState() => _BottomWidgetsState();
}

class _BottomWidgetsState extends State<BottomWidgets> {
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

  StreamSubscription<DocumentSnapshot>? _membersListener;
  final List<StreamSubscription<DocumentSnapshot>> _locationListeners = [];

  @override
  void initState() {
    super.initState();
    _listenToMembers();
    _setupVerificationCodeFocusListeners();
  }

  @override
void didUpdateWidget(BottomWidgets oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.activeSpaceId != oldWidget.activeSpaceId) {
    _listenToMembers(); // Re-fetch members when activeSpaceId changes
  }
}

  @override
  void dispose() {
    _membersListener?.cancel();
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();
    _spaceNameController.dispose();
    for (final controller in _verificationCodeControllers) {
      controller.dispose();
    }
    for (final node in _verificationCodeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _listenToMembers() {
  if (widget.activeSpaceId.isEmpty || widget.activeSpaceId == '') {
    _membersListener?.cancel();
    _membersListener = null;
    _locationListeners.forEach((listener) => listener.cancel());
    _locationListeners.clear();
    setState(() {
      _members = [];
      _spaceName = null;
      _verificationCode = null;
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
          title: const Text('Send Code'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Email'),
            onChanged: (value) => email = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
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
    'members': [user.uid], // Add the creator as the first member
    'verificationCode': verificationCode,
    'codeTimestamp': DateTime.now(),
    'createdAt': DateTime.now(),
  });

  // Create a chat room for the space and add the creator as the first member
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
      'members': FieldValue.arrayUnion([user.uid]),
    });

    // Add the user to the space chat room
    await _chatService.addMemberToSpaceChatRoom(spaceId, user.uid);

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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Column(
          children: [
            ServiceButtons(onButtonPressed: (label) {
              if (label == 'SOS') {
                Navigator.pushNamed(context, '/sos');
              }
            }),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
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
                         Container(
                          width: 100,
                          height: 2,
                          color: Colors.grey.shade700,
                          margin: const EdgeInsets.only(bottom: 8),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Text to Speech, Speech to Text",
                                  style: TextStyle(
                                    color: Color(0xFF6750A4),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.mic,
                                color: Color(0xFF6750A4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            CustomButton(
                              icon: Icons.people,
                              index: 0,
                              activeIndex: _activeIndex,
                              onPressed: (int newIndex) {
                                setState(() {
                                  _activeIndex = newIndex;
                                });
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
                        if (!_showCreateSpace &&
                            !_showJoinSpace &&
                            _activeIndex == 0 &&
                            widget.activeSpaceId.isEmpty) ...[
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              "My Space",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              "Create a new space or join an existing one today",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 150,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showCreateSpace = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6750A4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                  ),
                                  child: const Text(
                                    'Create Space',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 150,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _showJoinSpace = true;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6750A4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                  ),
                                  child: const Text(
                                    'Join Space',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
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
                            verificationCodeControllers: _verificationCodeControllers,
                            verificationCodeFocusNodes: _verificationCodeFocusNodes,
                            onJoinSpace: _joinSpace,
                            onCancel: () {
                              setState(() {
                                _showJoinSpace = false;
                              });
                            },
                          ),
                        if (_activeIndex == 0 && widget.activeSpaceId.isNotEmpty)
                          MemberListWidget(
                            members: _members,
                            onMemberPressed: widget.onMemberPressed,
                            selectedMemberId: _selectedMemberId,
                            activeSpaceId: widget.activeSpaceId,
                          ),
                          if (_activeIndex == 1)
                          const AddPlaceWidget(),
                        if (_activeIndex == 2)
                          MapContent(
                            onCategorySelected: (category) {
                              widget.onCategorySelected;
                            },
                          ),
                        if (_creatorId == _auth.currentUser?.uid &&
                            _activeIndex == 0 &&
                            widget.activeSpaceId.isNotEmpty)
                          VerificationCodeWidget(
                            verificationCode: _verificationCode ?? 'ABC - DEF',
                            onSendCode: _addPerson,
                          ),
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

   Future<String> _getAddressFromLatLng(LatLng latLng) async {
    try {
      final geocodingService = GeocodingService();
      final address = await geocodingService.getAddressFromLatLng(latLng);
      return address;
    } catch (e) {
      print('Error fetching address: $e');
      return 'Address unavailable';
    }
  }
}