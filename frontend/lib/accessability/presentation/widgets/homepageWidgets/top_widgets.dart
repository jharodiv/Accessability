import 'package:flutter/material.dart';

class Topwidgets extends StatefulWidget {
  final Function(bool) onOverlayChange;
  final GlobalKey inboxKey;
  final GlobalKey settingsKey;

  const Topwidgets({super.key, 
  required this.onOverlayChange,
  required this.inboxKey, 
  required this.settingsKey
  });

  @override
  _TopwidgetsState createState() => _TopwidgetsState();
}

class _TopwidgetsState extends State<Topwidgets> {
  bool _isDropdownOpen = false;
  final List<String> options = ['Circle One', 'Circle Two', 'Circle Three'];
  final List<String> oblongItems = [
    'Hotel',
    'Restaurant',
    'Bus',
    'Shopping',
    'Groceries'
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
          color: Colors.transparent,
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Settings button
                        GestureDetector(
                          key: widget.settingsKey,
                          onTap: () {
                            Navigator.pushNamed(context, '/settings');
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.settings,
                                color: Color(0xFF6750A4),
                                size: 25,
                              ),
                            ),
                          ),
                        ),
                        // My Space button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isDropdownOpen = !_isDropdownOpen;
                            });
                            widget.onOverlayChange(_isDropdownOpen);
                          },
                          child: Container(
                            width: 150,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Text(
                                    'My Space',
                                    style: TextStyle(
                                      color: Color(0xFF6750A4),
                                      fontWeight: FontWeight.bold,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(right: 10),
                                  child: Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Inbox button with the global key
                        GestureDetector(
                          key: widget.inboxKey, // Assign the key here
                          onTap: () {
                            Navigator.pushNamed(context, '/inbox');
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.chat,
                                color: Color(0xFF6750A4),
                                size: 25,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // The oblong items row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: oblongItems.map((item) {
                            return Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  item,
                                  style: const TextStyle(
                                    color: Color(0xFF6750A4),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
