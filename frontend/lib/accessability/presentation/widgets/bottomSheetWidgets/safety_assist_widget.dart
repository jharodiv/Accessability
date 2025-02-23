import 'package:flutter/material.dart';

class SafetyAssistWidget extends StatefulWidget {
  const SafetyAssistWidget({Key? key}) : super(key: key);

  @override
  State<SafetyAssistWidget> createState() => _SafetyAssistWidgetState();
}

class _SafetyAssistWidgetState extends State<SafetyAssistWidget> {
  final List<Map<String, dynamic>> contacts = [
    {
      "name": "Harold",
      "location": "Near Lingayen, Pangasinan (current location)",
      "arrival": "Since [date of arrival]",
      "update": "Last update 11 min. ago (last update location)",
    },
    {
      "name": "Binnashii",
      "location": "Near San Carlos, Pangasinan (current location)",
      "arrival": "Since [date of arrival]",
      "update": "Last update now. (last update location)",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.7,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100, // Adjust width as needed
                    height: 2, // Thin line
                    color: Colors.grey.shade700, // Dark grey color
                    margin: const EdgeInsets.only(
                        bottom: 8), // Space below the line
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Safety Assist",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Icon(
                        Icons.help_outline,
                        color: const Color(0xFF6750A4),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Add Emergency Contact (no background)
                  InkWell(
                    onTap: () {
                      // Handle add contact action
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            color: Color(0xFF6750A4),
                            size: 30,
                          ),
                          SizedBox(width: 15),
                          Text(
                            "Add Emergency Contact",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold, // Make the text bold
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),

                  // Contact List
                  ...contacts.map((contact) {
                    return Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            contact["name"],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact["location"],
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Text(
                                contact["arrival"],
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Text(
                                contact["update"],
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.call,
                                    color: Color(0xFF6750A4)),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.message,
                                    color: Color(0xFF6750A4)),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
