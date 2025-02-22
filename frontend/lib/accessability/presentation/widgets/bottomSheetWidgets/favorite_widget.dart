import 'package:flutter/material.dart';

class FavoriteWidget extends StatefulWidget {
  const FavoriteWidget({Key? key}) : super(key: key);

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  final List<Map<String, dynamic>> lists = [
    {
      "icon": Icons.favorite,
      "title": "Favorites",
      "subtitle": "Private · 0 places",
      "expanded": false
    },
    {
      "icon": Icons.flag,
      "title": "Want to go",
      "subtitle": "Private · 0 places",
      "expanded": false
    },
    {
      "icon": Icons.play_arrow,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ElevatedButton(
            onPressed: () {
              // Add new list action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade100,
              foregroundColor: Colors.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Center(child: Text("+ New List")),
          ),
        ),

        // "Your lists" Title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                leading: Icon(lists[index]["icon"], color: Colors.purple),
                title: Text(
                  lists[index]["title"],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(lists[index]["subtitle"]),
                trailing: IconButton(
                  icon: Icon(
                    lists[index]['expanded']
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                  onPressed: () => toggleExpansion(index),
                ),
                onTap: () => toggleExpansion(index),
              ),

              // Expandable Section
              if (lists[index]['expanded'])
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    "Expanded content for ${lists[index]['title']}",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),

              const Divider(),
            ],
          );
        }),
      ],
    );
  }
}
