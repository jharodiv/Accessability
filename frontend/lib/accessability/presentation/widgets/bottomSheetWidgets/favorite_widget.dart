import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';

class FavoriteWidget extends StatefulWidget {
  final VoidCallback? onPlaceAdded;

  const FavoriteWidget({super.key, this.onPlaceAdded});

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  // Each list represents a category of places.
  final List<Map<String, dynamic>> lists = [
    {
      "icon": Icons.favorite_border,
      "title": "Favorites",
      "subtitle": "Private · 0 places",
      "expanded": false,
    },
    {
      "icon": Icons.outlined_flag,
      "title": "Want to go",
      "subtitle": "Private · 0 places",
      "expanded": false,
    },
    {
      "icon": Icons.navigation_outlined,
      "title": "Visited",
      "subtitle": "Private · 0 places",
      "expanded": false,
    },
  ];

  /// When toggling expansion, collapse all other lists and,
  /// if the tapped list is expanding, load its places.
  void toggleExpansion(int index) {
    setState(() {
      // Collapse all other lists.
      for (int i = 0; i < lists.length; i++) {
        if (i == index) {
          lists[i]['expanded'] = !lists[i]['expanded'];
        } else {
          lists[i]['expanded'] = false;
        }
      }
    });

    // If the list is expanded, trigger a load for its places.
    if (lists[index]['expanded'] == true) {
      final category = lists[index]['title'];
      context
          .read<PlaceBloc>()
          .add(GetPlacesByCategoryEvent(category: category));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3, // Adjust the initial size as needed
      minChildSize: 0.3,
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
                    width: 100,
                    height: 2,
                    color: Colors.grey.shade700,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () async {
                        // Instead of showing a dialog, push a full-screen page.
                        final newListData =
                            await Navigator.pushNamed<Map<String, dynamic>>(
                          context,
                          '/addPlace',
                        );
                        print("Returned from /addPlace: $newListData");

                        // If user returns data from that screen, update your list accordingly.
                        if (newListData != null) {
                          setState(() {
                            lists.add({
                              "icon": Icons.list,
                              "title": newListData['title'] ?? "New List",
                              "subtitle": "Private · 0 places",
                              "expanded": false,
                            });
                          });
                          if (widget.onPlaceAdded != null) {
                            widget.onPlaceAdded!();
                          }
                        }
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
                  // Generate list items
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
                        // Expanded Section: show places for the category.
                        if (lists[index]['expanded'])
                          BlocBuilder<PlaceBloc, PlaceState>(
                            builder: (context, state) {
                              if (state is PlaceOperationLoading) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              } else if (state is PlacesLoaded) {
                                final places = state.places;
                                // Update subtitle to show count
                                lists[index]['subtitle'] =
                                    "Private · ${places.length} places";
                                return places.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text("No places available."),
                                      )
                                    : Column(
                                        children: places.map((Place place) {
                                          return ListTile(
                                            title: Text(place.name),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red),
                                              onPressed: () {
                                                // Dispatch delete event and refresh list.
                                                context.read<PlaceBloc>().add(
                                                    DeletePlaceEvent(
                                                        placeId: place.id));
                                                final category =
                                                    lists[index]['title'];
                                                context.read<PlaceBloc>().add(
                                                    GetPlacesByCategoryEvent(
                                                        category: category));
                                              },
                                            ),
                                          );
                                        }).toList(),
                                      );
                              } else if (state is PlaceOperationError) {
                                return Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(state.message),
                                );
                              }
                              return const SizedBox.shrink();
                            },
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
