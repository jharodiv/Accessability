import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_bloc.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_event.dart';
import 'package:accessability/accessability/logic/bloc/place/bloc/place_state.dart';
import 'package:accessability/accessability/data/model/place.dart';
import 'package:provider/provider.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'add_list_modal.dart'; // Import the modal widget

// NEW imports
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/service_buttons.dart';

class FavoriteWidget extends StatefulWidget {
  final VoidCallback? onPlaceAdded;
  final DraggableScrollableController? controller;

  final void Function(Place)?
      onShowPlace; // Callback to show a place on the map

  // NEW: expose needed callbacks and currentLocation so ServiceButtons can work here too
  final LatLng? currentLocation;
  final Future<void> Function()? onMapViewPressed;
  final VoidCallback? onCenterPressed;
  final void Function(String)? onServiceButtonPressed;

  const FavoriteWidget({
    Key? key,
    this.controller, // <- add this

    this.onShowPlace,
    this.onPlaceAdded,
    this.currentLocation,
    this.onMapViewPressed,
    this.onCenterPressed,
    this.onServiceButtonPressed,
  }) : super(key: key);

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  // Using localization keys for the default list categories.
  final List<Map<String, dynamic>> lists = [
    {
      "icon": Icons.favorite_border,
      "title": "favorites", // key in translation files
      "expanded": false,
    },
    {
      "icon": Icons.outlined_flag,
      "title": "want_to_go", // key in translation files
      "expanded": false,
    },
    {
      "icon": Icons.navigation_outlined,
      "title": "visited", // key in translation files
      "expanded": false,
    },
  ];

  // Draggable sheet controller + expansion state (copied from LocationWidgets)
  late final DraggableScrollableController _draggableController;
  bool _isExpanded = false;
  late final double _expandThreshold = 0.8;
  VoidCallback? _controllerListener;

  void _expandCategory(String categoryKey) {
    setState(() {
      for (int i = 0; i < lists.length; i++) {
        lists[i]['expanded'] = (lists[i]['title'] == categoryKey);
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
  void initState() {
    super.initState();

    _draggableController = widget.controller ?? DraggableScrollableController();

    // attach listener to keep _isExpanded in sync with controller.size
    _controllerListener = () {
      try {
        final size = _draggableController.size;
        final expanded = size >= _expandThreshold;
        if (expanded != _isExpanded) {
          setState(() => _isExpanded = expanded);
        }
      } catch (_) {
        // ignore if size not available yet
      }
    };
    _draggableController.addListener(_controllerListener!);

    // Optional: if you want to animate to an initial size after build, uncomment:
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   _draggableController.animateTo(0.5, duration: Duration(milliseconds: 250), curve: Curves.easeOut);
    // });
  }

  @override
  void dispose() {
    if (_controllerListener != null) {
      _draggableController.removeListener(_controllerListener!);
    }
    // Only dispose when we created it locally:
    if (widget.controller == null) {
      _draggableController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      controller: _draggableController,
      expand: true,
      initialChildSize:
          0.5, // <- the "default" height where it should sit initially
      minChildSize:
          0.3, // <- allow user to drag it further down (smaller = lower)
      maxChildSize: 1.0, // allow it to reach the utmost top
      builder: (BuildContext context, ScrollController scrollController) {
        // NOTE: ServiceButtons is placed OUTSIDE the white container below (same visual position as LocationWidgets)
        return Column(
          children: [
            const SizedBox(height: 8),

            // --- OUTSIDE ServiceButtons (above the main container) ---
            IgnorePointer(
              ignoring: _isExpanded,
              child: Builder(builder: (ctx) {
                // show/hide with animation like LocationWidgets
                final showButtons = !_isExpanded;
                return AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: showButtons ? 1.0 : 0.0,
                    child: showButtons
                        ? ServiceButtons(
                            onButtonPressed:
                                widget.onServiceButtonPressed ?? (label) {},
                            currentLocation: widget.currentLocation,
                            onMapViewPressed: widget.onMapViewPressed,
                            onCenterPressed: widget.onCenterPressed ??
                                () {
                                  if (widget.currentLocation == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'locationNotAvailable'.tr())),
                                    );
                                    return;
                                  }
                                },
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ),

            const SizedBox(height: 10),

            // --- main sheet content (white container) ---
            Expanded(
              child: SafeArea(
                top:
                    _isExpanded, // only add top safe inset when sheet is expanded
                bottom: false,
                child: Container(
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
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
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

                                final result = await showModalBottomSheet<
                                    Map<String, dynamic>>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (BuildContext context) {
                                    return const AddListModal();
                                  },
                                );

                                if (result != null &&
                                    result.containsKey("category") &&
                                    result.containsKey("places")) {
                                  final newCategory =
                                      result["category"] as String;
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Center(child: Text("new_list".tr())),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: Text(
                                  "your_lists".tr(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...List.generate(lists.length, (index) {
                            final String categoryKey = lists[index]['title'];
                            return BlocBuilder<PlaceBloc, PlaceState>(
                              builder: (context, state) {
                                int count = 0;
                                if (state is PlacesLoaded) {
                                  count = state.places
                                      .where((place) =>
                                          place.category == categoryKey)
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
                                        categoryKey.tr(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "private_places"
                                            .tr(args: [count.toString()]),
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.grey,
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
                                                place.category == categoryKey)
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
                                                  widget.onShowPlace
                                                      ?.call(place);
                                                } else if (value == 'delete') {
                                                  context.read<PlaceBloc>().add(
                                                        UpdatePlaceCategoryEvent(
                                                          placeId: place.id,
                                                          newCategory: 'none',
                                                        ),
                                                      );
                                                  Future.delayed(
                                                      const Duration(
                                                          milliseconds: 500),
                                                      () {
                                                    context.read<PlaceBloc>().add(
                                                        const GetAllPlacesEvent());
                                                  });
                                                }
                                              },
                                              itemBuilder:
                                                  (BuildContext context) =>
                                                      <PopupMenuEntry<String>>[
                                                PopupMenuItem<String>(
                                                  value: 'show',
                                                  child:
                                                      Text("show_on_map".tr()),
                                                ),
                                                PopupMenuItem<String>(
                                                  value: 'delete',
                                                  child: Text("delete".tr()),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    const Divider(
                                        indent: 16, endIndent: 16, height: 0),
                                  ],
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
