import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:AccessAbility/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:AccessAbility/accessability/firebaseServices/models/place.dart';
import 'package:provider/provider.dart';
import 'package:AccessAbility/accessability/themes/theme_provider.dart';
import 'add_list_modal.dart'; // Import the modal widget

class FavoriteWidget extends StatefulWidget {
  final VoidCallback? onPlaceAdded;
  final void Function(Place)?
      onShowPlace; // Callback to show a place on the map

  const FavoriteWidget({Key? key, this.onShowPlace, this.onPlaceAdded})
      : super(key: key);

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  final List<Map<String, dynamic>> lists = [
    {
      "icon": Icons.favorite_border,
      "title": "Favorites",
      "expanded": false,
    },
    {
      "icon": Icons.outlined_flag,
      "title": "Want to go",
      "expanded": false,
    },
    {
      "icon": Icons.navigation_outlined,
      "title": "Visited",
      "expanded": false,
    },
  ];

  void _expandCategory(String categoryName) {
    setState(() {
      for (int i = 0; i < lists.length; i++) {
        lists[i]['expanded'] = (lists[i]['title'] == categoryName);
      }
    });
  }

  void toggleExpansion(int index) {
    setState(() {
      for (int i = 0; i < lists.length; i++) {
        lists[i]['expanded'] = (i == index) ? !lists[i]['expanded'] : false;
      }
    });

    if (lists[index]['expanded'] == true) {
      context.read<PlaceBloc>().add(const GetAllPlacesEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.3,
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
                  const SizedBox(height: 5),
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

                          for (Place place in placesToUpdate) {
                            context.read<PlaceBloc>().add(
                                  UpdatePlaceCategoryEvent(
                                    placeId: place.id,
                                    newCategory: newCategory,
                                  ),
                                );
                          }

                          final existingIndex = lists.indexWhere(
                            (item) => item["title"] == newCategory,
                          );

                          if (existingIndex == -1) {
                            setState(() {
                              lists.add({
                                "icon": Icons.list,
                                "title": newCategory,
                                "expanded": false,
                              });
                            });
                          }

                          _expandCategory(newCategory);
                          context
                              .read<PlaceBloc>()
                              .add(const GetAllPlacesEvent());
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
                  ...List.generate(lists.length, (index) {
                    final categoryTitle = lists[index]['title'];
                    return BlocBuilder<PlaceBloc, PlaceState>(
                      builder: (context, state) {
                        int count = 0;
                        if (state is PlacesLoaded) {
                          count = state.places
                              .where((place) => place.category == categoryTitle)
                              .length;
                        }
                        return Column(
                          children: [
                            ListTile(
                              leading: Icon(
                                lists[index]["icon"],
                                color: const Color(0xFF6750A4),
                              ),
                              title: Text(
                                categoryTitle,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                "Private · $count places",
                                style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white : Colors.grey,
                                ),
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
                            if (lists[index]['expanded'] &&
                                state is PlacesLoaded)
                              Column(
                                children: state.places
                                    .where((place) =>
                                        place.category == categoryTitle)
                                    .map((Place place) {
                                  return ListTile(
                                    title: Text(
                                      place.name,
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    trailing: PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert,
                                          color: Colors.red),
                                      onSelected: (value) {
                                        if (value == 'show') {
                                          widget.onShowPlace?.call(place);
                                        } else if (value == 'delete') {
                                          context.read<PlaceBloc>().add(
                                                UpdatePlaceCategoryEvent(
                                                  placeId: place.id,
                                                  newCategory: 'none',
                                                ),
                                              );
                                          Future.delayed(
                                              const Duration(milliseconds: 500),
                                              () {
                                            context
                                                .read<PlaceBloc>()
                                                .add(const GetAllPlacesEvent());
                                          });
                                        }
                                      },
                                      itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'show',
                                          child: Text('Show on Map'),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            const Divider(indent: 16, endIndent: 16, height: 0),
                          ],
                        );
                      },
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
