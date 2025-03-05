import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:AccessAbility/accessability/firebaseServices/place/geocoding_service.dart';

class MemberListWidget extends StatefulWidget {
  final String activeSpaceId;
  final List<Map<String, dynamic>> members;
  final Function(LatLng, String) onMemberPressed;
  final String? selectedMemberId;

  const MemberListWidget({
    super.key,
    required this.activeSpaceId,
    required this.members,
    required this.onMemberPressed,
    required this.selectedMemberId,
  });

  @override
  _MemberListWidgetState createState() => _MemberListWidgetState();
}

class _MemberListWidgetState extends State<MemberListWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedMemberId;
  

    @override
Widget build(BuildContext context) {
  if (widget.activeSpaceId.isEmpty) {
    return const Center(
      child: Text(
        '',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  if (widget.members.isEmpty) {
    return const Center(
      child: CircularProgressIndicator(), // Show loading indicator
    );
  }

  return Column(
    children: widget.members
        .where((member) => member['uid'] != _auth.currentUser?.uid)
        .map((member) => GestureDetector(
              onTap: () async {
                setState(() {
                  _selectedMemberId = member['uid'];
                });

                final locationSnapshot = await _firestore
                    .collection('UserLocations')
                    .doc(member['uid'])
                    .get();
                final locationData = locationSnapshot.data();
                if (locationData != null) {
                  final lat = locationData['latitude'];
                  final lng = locationData['longitude'];
                  final address =
                      await _getAddressFromLatLng(LatLng(lat, lng));

                  setState(() {
                    member['address'] = address;
                    member['lastUpdate'] = locationData['timestamp'];
                  });

                  widget.onMemberPressed(LatLng(lat, lng), member['uid']);
                }
              },
              child: Container(
                color: _selectedMemberId == member['uid']
                    ? const Color(0xFF6750A4)
                    : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member['profilePicture'] != null &&
                            member['profilePicture'].startsWith('http')
                        ? NetworkImage(member['profilePicture'])
                        : const AssetImage(
                                'assets/images/others/default_profile.png')
                            as ImageProvider,
                  ),
                  title: Text(
                    member['username'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location: ${member['address'] ?? 'Fetching address...'}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      if (member['lastUpdate'] != null)
                        Text(
                          'Last location update: ${_getTimeDifference((member['lastUpdate'] as Timestamp).toDate())}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.chat,
                      color: Color(0xFF6750A4),
                    ),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/chatconvo',
                        arguments: {
                          'receiverUsername': member['username'],
                          'receiverID': member['uid'],
                          'receiverProfilePicture': member['profilePicture'],
                        },
                      );
                    },
                  ),
                ),
              ),
            ))
        .toList(),
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

  String _getTimeDifference(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute(s) ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour(s) ago';
    } else {
      return '${difference.inDays} day(s) ago';
    }
  }
}