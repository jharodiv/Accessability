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

  /// Controls whether to show the overlay with Safety Assist details
  bool showHelp = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- Main Content in DraggableScrollableSheet ---
        DraggableScrollableSheet(
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
                      // Drag handle
                      Container(
                        width: 100,
                        height: 2,
                        color: Colors.grey.shade700,
                        margin: const EdgeInsets.only(bottom: 8),
                      ),
                      const SizedBox(height: 15),

                      // Row with Safety Assist label and clickable help icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Safety Assist",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.help_outline,
                              color: Color(0xFF6750A4),
                            ),
                            onPressed: () {
                              print(
                                  "Help icon tapped!"); // Should print in the console
                              print("Current state of showHelp: $showHelp");

                              setState(() {
                                showHelp = true; // Show the help overlay
                              });
                            },
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
                                  fontWeight: FontWeight.bold,
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
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
        ),

        // --- Overlay for Safety Assist Explanation ---
        if (showHelp)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  showHelp = false; // Dismiss the overlay when tapped outside
                });
              },
              child: Container(
                color: Colors.black54, // semi-transparent background
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Scroll if text is long
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          const Text(
                            "Safety Assist",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Your explanation text
                          const Text(
                            "AccessAbility prioritizes your safety and peace of mind by offering "
                            "a feature that allows you to designate safety contacts within the app. "
                            "These contacts can be trusted family members, friends, or caregivers "
                            "who will be notified in case of an emergency. The app allows you to "
                            "easily add, update, or remove safety contacts, ensuring that the people "
                            "who matter most to you are always informed and ready to assist when needed.\n\n"
                            "In real-time geolocation, you can quickly activate the SOS feature, which "
                            "sends an instant alert to all your designated safety contacts. This alert "
                            "includes your real-time location and any other critical information that "
                            "can help your contacts respond quickly. By keeping your safety contacts "
                            "updated, you ensure that help is just a few taps away, no matter where you "
                            "are.\n\nThe SOS feature offers peace of mind by ensuring that everyone "
                            "around you is aware that you need assistance. Your first listed contact "
                            "receives the alert as soon as it triggers. This means that in case of an "
                            "emergency, all your contacts are informed. With AccessAbility, your safety "
                            "is a top priority, and staying in the app helps you remain connected to "
                            "those who can provide support in critical moments.",
                            textAlign: TextAlign.justify,
                          ),
                          const SizedBox(height: 20),

                          // Close button
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                showHelp = false; // Dismiss the overlay
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6750A4),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text("Close"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
