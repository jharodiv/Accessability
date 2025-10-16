import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/member_list_widget.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/verification_code_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpaceMembersScreen extends StatelessWidget {
  final String spaceId;

  const SpaceMembersScreen({super.key, required this.spaceId});

  Stream<List<Map<String, dynamic>>> _fetchMembers() {
    print("🔥 Fetching members for spaceId: $spaceId");

    return FirebaseFirestore.instance
        .collection('Spaces')
        .doc(spaceId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) {
        print("⚠️ Space not found: $spaceId");
        return [];
      }

      final data = doc.data() ?? {};
      final List<String> memberIds = List<String>.from(data['members'] ?? []);
      print("👥 Found ${memberIds.length} member IDs: $memberIds");

      if (memberIds.isEmpty) return [];

      // Fetch user documents based on those IDs
      final usersQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', whereIn: memberIds)
          .get();

      final users = usersQuery.docs.map((u) => u.data()).toList();
      print("✅ Loaded ${users.length} user profiles");

      return users;
    });
  }

  @override
  Widget build(BuildContext context) {
    print("🚀 Opened SpaceMembersScreen with spaceId: $spaceId");

    return Scaffold(
      appBar: AppBar(title: const Text('Space Members')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _fetchMembers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print("⏳ Waiting for member data...");
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("❌ Firestore error: ${snapshot.error}");
            return Center(child: Text('Error loading members.'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            print("⚠️ No members found for spaceId: $spaceId");
            return const Center(child: Text('No members found.'));
          }

          final members = snapshot.data!;
          print("✅ Successfully loaded ${members.length} members for $spaceId");

          return MemberListWidget(
            activeSpaceId: spaceId,
            members: members,
            onMemberPressed: (location, memberId) {
              print("🖱️ Member pressed: $memberId");
            },
            onAddPerson: () async {
              print("➕ Add Person tapped for space: $spaceId");

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception("No authenticated user.");

                final userId = user.uid;
                final userDoc = await FirebaseFirestore.instance
                    .collection('Users')
                    .doc(userId)
                    .get();
                final currentActiveSpaceId = userDoc.data()?['activeSpaceId'];

                if (currentActiveSpaceId != spaceId) {
                  // 🔄 Switch the active space for the whole app
                  print("Switching active space to $spaceId...");
                  await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(userId)
                      .update({'activeSpaceId': spaceId});

                  // Wait a little to ensure Firestore update propagates
                  await Future.delayed(const Duration(milliseconds: 500));
                  print("✅ Active space switched to $spaceId!");
                } else {
                  print("✅ Space $spaceId is already active.");
                }

                // Fetch the space name dynamically
                final spaceDoc = await FirebaseFirestore.instance
                    .collection('Spaces')
                    .doc(spaceId)
                    .get();
                final spaceName =
                    (spaceDoc.data()?['name'] as String?)?.trim() ??
                        'Unnamed Space';

                Navigator.pop(context); // Close loading

                // Navigate to VerificationCodeScreen with the dynamic space name
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VerificationCodeScreen(
                      spaceId: spaceId,
                      spaceName: spaceName,
                    ),
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                print("❌ Error switching space: $e");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to switch space')),
                );
              }
            },
          );
        },
      ),
    );
  }
}
