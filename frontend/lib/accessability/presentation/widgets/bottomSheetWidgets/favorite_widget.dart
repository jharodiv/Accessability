import 'package:flutter/material.dart';

class FavoriteWidget extends StatefulWidget {
  const FavoriteWidget({Key? key}) : super(key: key);

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  final List<Map<String, dynamic>> lists = [
    {
      "icon": Icons.favorite_border,
      "title": "Favorites",
      "subtitle": "Private · 0 places",
      "expanded": false
    },
    {
      "icon": Icons.outlined_flag,
      "title": "Want to go",
      "subtitle": "Private · 0 places",
      "expanded": false
    },
    {
      "icon": Icons.assistant_navigation,
      "title": "Visited",
      "subtitle": "Private · 0 places",
      "expanded": false
    },
  ];

  void toggleExpansion(int index) {
    setState(() {
      lists[index]['expanded'] = !lists[index]['expanded'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // New List Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              // Add new list action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD8CFE8),
              foregroundColor: const Color(0xFF6750A4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Center(child: Text("+ New List")),
          ),
        ),

        // "Your lists" Title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            "Your lists",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        // List Items
        ...List.generate(lists.length, (index) {
          return Column(
            children: [
              ListTile(
                leading:
                    Icon(lists[index]["icon"], color: const Color(0xFF6750A4)),
                title: Text(
                  lists[index]["title"],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  lists[index]["subtitle"],
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: Icon(
                    lists[index]['expanded']
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => toggleExpansion(index),
                ),
                onTap: () => toggleExpansion(index),
              ),

              // Expandable Section (if needed)
              if (lists[index]['expanded'])
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Expanded content for ${lists[index]['title']}",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),

              const Divider(indent: 16, endIndent: 16, height: 0),
            ],
          );
        }),
      ],
    );
  }
}
