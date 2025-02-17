import 'package:flutter/material.dart';

class BottomWidgets extends StatefulWidget {
  final ScrollController scrollController;

  const BottomWidgets({Key? key, required this.scrollController}) : super(key: key);

  @override
  _BottomWidgetsState createState() => _BottomWidgetsState();
}

class _BottomWidgetsState extends State<BottomWidgets> {
  int _activeIndex = 0; // 0: People, 1: Buildings, 2: Map

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.1,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
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
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Search Location",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ),
                    onChanged: (value) {
                      // Handle search logic here
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton(Icons.people, 0),
                      _buildButton(Icons.business, 1),
                      _buildButton(Icons.map, 2),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildContent(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(IconData icon, int index) {
    bool isActive = _activeIndex == index; // Check if the button is active
    return SizedBox(
      width: 100, // Set the desired width for the button
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _activeIndex = index; // Update the active index
          });
        },
        child: Icon(
          icon,
          color: isActive ? Colors.white : const Color(0xFF6750A4), // Change icon color
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isActive ? const Color(0xFF6750A4) : Colors.white, // Change background color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Optional: round the button corners
          ),
          padding: const EdgeInsets.all(16), // Add padding to center the icon
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeIndex) {
      case 0:
        return const Text("People Content"); // Replace with actual content
      case 1:
        return const Text("Buildings Content"); // Replace with actual content
      case 2:
        return const Text("Map Content"); // Replace with actual content
      default:
        return const SizedBox.shrink();
    }
  }
}