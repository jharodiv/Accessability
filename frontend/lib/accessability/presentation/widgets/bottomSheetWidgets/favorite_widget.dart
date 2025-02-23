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
      "icon": Icons.navigation_outlined,
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
    return DraggableScrollableSheet(
      initialChildSize: 0.5, // Adjust the initial size as needed
      minChildSize: 0.5, // Minimum size of the sheet
      maxChildSize: 0.8, // Maximum size of the sheet
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
                    height: 5,
                  ),
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
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          "Your lists",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  // List Items
                  ...List.generate(lists.length, (index) {
                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(lists[index]["icon"],
                              color: const Color(0xFF6750A4)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
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
              ),
            ),
          ),
        );
      },
    );
  }
}
