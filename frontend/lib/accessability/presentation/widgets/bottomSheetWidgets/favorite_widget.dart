import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'add_list_modal.dart'; // Import the modal widget

class FavoriteWidget extends StatefulWidget {
  final VoidCallback? onPlaceAdded;

  const FavoriteWidget({super.key, this.onPlaceAdded});

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  // Fixed list of categories (plus potential new ones).
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

  /// Collapses all categories, expands the one matching [categoryName].
  void _expandCategory(String categoryName) {
    setState(() {
      for (int i = 0; i < lists.length; i++) {
        // Expand only the matched category, collapse others
        lists[i]['expanded'] = (lists[i]['title'] == categoryName);
      }
    });
  }

  /// When toggling expansion, collapse all other lists.
  /// If the tapped list is expanding, trigger a fetch of all places.
  void toggleExpansion(int index) {
    setState(() {
      for (int i = 0; i < lists.length; i++) {
        lists[i]['expanded'] = (i == index) ? !lists[i]['expanded'] : false;
      }
    });

    if (lists[index]['expanded'] == true) {
      // Fetch all places; we'll filter them by category in the UI.
      context.read<PlaceBloc>().add(const GetAllPlacesEvent());
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
                  // "+ New List" button opens a modal bottom sheet.
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: () async {
                        // Fetch all places before opening the modal.
                        context
                            .read<PlaceBloc>()
                            .add(const GetAllPlacesEvent());

                        final result =
                            await showModalBottomSheet<Map<String, dynamic>>(
                          context: context,
                          isScrollControlled: true,
                          builder: (BuildContext context) {
                            return const AddListModal();
                          },
                        );

                        if (result != null &&
                            result.containsKey("category") &&
                            result.containsKey("places")) {
                          final newCategory = result["category"] as String;
                          final placesToUpdate =
                              result["places"] as List<Place>;

                          // For each selected place, update its category in Firestore.
                          for (Place place in placesToUpdate) {
                            context.read<PlaceBloc>().add(
                                  UpdatePlaceCategoryEvent(
                                    placeId: place.id,
                                    newCategory: newCategory,
                                  ),
                                );
                          }

                          // See if this category already exists
                          final existingIndex = lists.indexWhere(
                            (item) => item["title"] == newCategory,
                          );

                          if (existingIndex == -1) {
                            // If not found, add a new category (0 places as a placeholder).
                            setState(() {
                              lists.add({
                                "icon": Icons.list,
                                "title": newCategory,
                                "subtitle": "Private · 0 places",
                                "expanded": false,
                              });
                            });
                          }

                          // Expand the relevant category so user sees it immediately.
                          _expandCategory(newCategory);

                          // Re-fetch places so the new count is reflected in the UI.
                          context
                              .read<PlaceBloc>()
                              .add(const GetAllPlacesEvent());

                          // Notify parent if needed
                          widget.onPlaceAdded?.call();
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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Generate list items for each category.
                  ...List.generate(lists.length, (index) {
                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            lists[index]["icon"],
                            color: const Color(0xFF6750A4),
                          ),
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
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              } else if (state is PlacesLoaded) {
                                // Filter all places based on the current category.
                                final categoryTitle = lists[index]['title'];
                                final filteredPlaces = state.places
                                    .where((place) =>
                                        place.category == categoryTitle)
                                    .toList();

                                // Update subtitle to show correct count.
                                lists[index]['subtitle'] =
                                    "Private · ${filteredPlaces.length} places";

                                return Column(
                                  children: filteredPlaces.map((Place place) {
                                    return ListTile(
                                      title: Text(place.name),
                                      trailing: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert,
                                            color: Colors.red),
                                        onSelected: (value) {
                                          if (value == 'remove') {
                                            // Update the place's category to an empty string (or null) to effectively remove it.
                                            context.read<PlaceBloc>().add(
                                                  UpdatePlaceCategoryEvent(
                                                    placeId: place.id,
                                                    newCategory:
                                                        'none', // Use '' or null instead of 'none'
                                                  ),
                                                );
                                            // Refresh after updating
                                            context
                                                .read<PlaceBloc>()
                                                .add(const GetAllPlacesEvent());
                                          } else if (value == 'delete') {
                                            // Delete the place entirely
                                            context.read<PlaceBloc>().add(
                                                  UpdatePlaceCategoryEvent(
                                                    placeId: place.id,
                                                    newCategory:
                                                        'none', // Use '' or null instead of 'none'
                                                  ),
                                                );
                                            // Refresh after updating
                                            context
                                                .read<PlaceBloc>()
                                                .add(const GetAllPlacesEvent());
                                          }
                                        },
                                        itemBuilder: (BuildContext context) =>
                                            <PopupMenuEntry<String>>[
                                          const PopupMenuItem<String>(
                                            value: 'remove',
                                            child: Text('Remove from Category'),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
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
