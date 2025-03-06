import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/emergency_contact.dart';
import 'package:AccessAbility/accessability/logic/bloc/emergency/bloc/emergency_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/emergency/bloc/emergency_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/emergency/bloc/emergency_state.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';

class SafetyAssistWidget extends StatefulWidget {
  final String uid;
  const SafetyAssistWidget({super.key, required this.uid});

  @override
  State<SafetyAssistWidget> createState() => _SafetyAssistWidgetState();
}

class _SafetyAssistWidgetState extends State<SafetyAssistWidget> {
  @override
  void initState() {
    super.initState();
    BlocProvider.of<EmergencyBloc>(context)
        .add(FetchEmergencyContactsEvent(uid: widget.uid));
  }

  void _showAddEmergencyContactDialog() {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final arrivalController = TextEditingController();
    final updateController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add Emergency Contact"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: "Location"),
                ),
                TextField(
                  controller: arrivalController,
                  decoration: const InputDecoration(labelText: "Arrival"),
                ),
                TextField(
                  controller: updateController,
                  decoration: const InputDecoration(labelText: "Update"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final contact = EmergencyContact(
                  name: nameController.text,
                  location: locationController.text,
                  arrival: arrivalController.text,
                  update: updateController.text,
                );
                BlocProvider.of<EmergencyBloc>(context).add(
                  AddEmergencyContactEvent(uid: widget.uid, contact: contact),
                );
                Navigator.of(context).pop();
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.7,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 2,
                    color: Colors.grey.shade700,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Safety Assist",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      Icon(
                        Icons.help_outline,
                        color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: _showAddEmergencyContactDialog,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            color: isDarkMode ? Colors.white : const Color(0xFF6750A4),
                            size: 30,
                          ),
                          const SizedBox(width: 15),
                          Text(
                            "Add Emergency Contact",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  BlocBuilder<EmergencyBloc, EmergencyState>(
                    builder: (context, state) {
                      if (state is EmergencyLoading) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (state is EmergencyContactsLoaded) {
                        final contacts = state.contacts;
                        if (contacts.isEmpty) {
                          return Text(
                            "No emergency contacts added yet.",
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          );
                        }
                        return Column(
                          children: contacts.map((contact) {
                            return Column(
                              children: [
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.grey,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  title: Text(
                                    contact.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact.location,
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        contact.arrival,
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        contact.update,
                                        style: TextStyle(
                                          color: isDarkMode ? Colors.white : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.call,
                                            color: isDarkMode ? Colors.white : const Color(0xFF6750A4)),
                                        onPressed: () {},
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.message,
                                            color: isDarkMode ? Colors.white : const Color(0xFF6750A4)),
                                        onPressed: () {},
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () {
                                          if (contact.id != null) {
                                            BlocProvider.of<EmergencyBloc>(context)
                                                .add(
                                              DeleteEmergencyContactEvent(
                                                  uid: widget.uid,
                                                  contactId: contact.id!),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                              ],
                            );
                          }).toList(),
                        );
                      } else if (state is EmergencyOperationError) {
                        return Text(
                          state.message,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}