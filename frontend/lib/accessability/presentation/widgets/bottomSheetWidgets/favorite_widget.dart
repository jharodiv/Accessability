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
  final void Function(Place)? onShowPlace;
  final LatLng? currentLocation;
  final Future<void> Function()? onMapViewPressed;
  final VoidCallback? onCenterPressed;
  final void Function(String)? onServiceButtonPressed;
  final Future<void> Function()? onShowMyInfoPressed;
  final bool isRerouting;

  const FavoriteWidget({
    Key? key,
    this.controller,
    this.onShowPlace,
    this.onPlaceAdded,
    this.currentLocation,
    this.onMapViewPressed,
    this.onCenterPressed,
    this.onServiceButtonPressed,
    this.onShowMyInfoPressed,
    this.isRerouting = false,
  }) : super(key: key);

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  final List<Map<String, dynamic>> lists = [
    {"icon": Icons.favorite, "title": "favorites", "expanded": false},
    {"icon": Icons.outlined_flag, "title": "want_to_go", "expanded": false},
    {"icon": Icons.navigation_outlined, "title": "visited", "expanded": false},
  ];

  // Draggable sheet controller + expansion state
  late final DraggableScrollableController _draggableController;
  bool _isExpanded = false;
  late final double _expandThreshold = 0.8;
  VoidCallback? _controllerListener;

  // sheet sizing constants
  final double _sheetMinChildSize = 0.30;
  final double _sheetDefaultInitial = 0.35;
  final double _sheetMaxChildSize = 1.0;
  bool _isAtTop = false;

  // service-area animation state
  double _serviceAreaFactor = 1.0;
  bool _serviceVisible = true;

  // attachment / pending animation helpers
  bool _sheetAttached = false;
  double? _pendingAnimateTarget;
  Duration _pendingAnimateDuration = const Duration(milliseconds: 300);
  Curve _pendingAnimateCurve = Curves.easeOut;
  bool _createdControllerLocally = false;
  bool _mapSheetOpening = false;

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
      // Always refresh data when expanding a category
      context.read<PlaceBloc>().add(const GetAllPlacesEvent());
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[FavoriteWidget] initState (isRerouting=${widget.isRerouting})');

    // choose whether to reuse passed controller or create our own
    if (widget.controller != null) {
      try {
        debugPrint(
            '[FavoriteWidget] parent passed a controller, checking isAttached...');
        if (widget.controller!.isAttached) {
          debugPrint(
              '[FavoriteWidget] passed controller is already attached — creating local controller instead');
          _draggableController = DraggableScrollableController();
          _createdControllerLocally = true;
        } else {
          debugPrint('[FavoriteWidget] reusing passed controller instance');
          _draggableController = widget.controller!;
          _createdControllerLocally = false;
        }
      } catch (e, st) {
        debugPrint(
            '[FavoriteWidget] error checking passed controller.isAttached: $e\n$st — using local controller');
        _draggableController = DraggableScrollableController();
        _createdControllerLocally = true;
      }
    } else {
      debugPrint(
          '[FavoriteWidget] no controller passed — creating local controller');
      _draggableController = DraggableScrollableController();
      _createdControllerLocally = true;
    }

    // copy service-area fade logic
    const double _hideThreshold = 0.55;
    final double _fadeStart = _sheetDefaultInitial;
    const double _factorDirtyThreshold = 0.02;

    _controllerListener = () {
      try {
        final size = _draggableController.size;

        // compute top state
        final bool atTop = size >= 0.995;

        // Map size -> factor in a smooth linear ramp between _fadeStart.._hideThreshold
        double factor;
        if (size <= _fadeStart) {
          factor = 1.0;
        } else if (size >= _hideThreshold) {
          factor = 0.0;
        } else {
          factor = 1.0 - (size - _fadeStart) / (_hideThreshold - _fadeStart);
        }
        factor = factor.clamp(0.0, 1.0);

        final bool factorChanged =
            (factor - _serviceAreaFactor).abs() > _factorDirtyThreshold;
        if (factorChanged || atTop != _isAtTop) {
          setState(() {
            _serviceAreaFactor = factor;
            _isAtTop = atTop;
          });
        }
      } catch (_) {}
    };

    _draggableController.addListener(_controllerListener!);

    // If rerouting already true on init, queue collapse safely once frame rendered
    if (widget.isRerouting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _safeAnimateSheetTo(
            _sheetMinChildSize,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } catch (_) {
          // ignore if animateTo not available yet
        }
      });
    }
  }

  // ----------------- _safeAnimateSheetTo -----------------
  Future<void> _safeAnimateSheetTo(double target,
      {Duration duration = const Duration(milliseconds: 300),
      Curve curve = Curves.easeOut}) async {
    if (!mounted) {
      debugPrint(
          '[FavoriteWidget] _safeAnimateSheetTo called but not mounted, target=$target');
      return;
    }

    debugPrint(
        '[FavoriteWidget] _safeAnimateSheetTo(target=$target, attached=$_sheetAttached)');

    if (_sheetAttached) {
      try {
        debugPrint(
            '[FavoriteWidget] animating controller to $target NOW (isAttached=${_draggableController.isAttached})');
        await _draggableController.animateTo(target,
            duration: duration, curve: curve);
        double after = 0;
        try {
          after = _draggableController.size;
        } catch (_) {}
        debugPrint(
            '[FavoriteWidget] animateTo completed to $target, controller.size=$after');
      } catch (e, st) {
        debugPrint('[FavoriteWidget] animateTo failed: $e\n$st');
        try {
          debugPrint(
              '[FavoriteWidget] controller.size on failure=${_draggableController.size}');
        } catch (_) {}
      }
      return;
    }

    // queue it to run once sheet attaches
    _pendingAnimateTarget = target;
    _pendingAnimateDuration = duration;
    _pendingAnimateCurve = curve;
    debugPrint(
        '[FavoriteWidget] queued animateTo($target) — sheet not attached yet');
  }

  @override
  void didUpdateWidget(covariant FavoriteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    debugPrint(
        '[FavoriteWidget] didUpdateWidget: old.isRerouting=${oldWidget.isRerouting} new.isRerouting=${widget.isRerouting}');

    // If rerouting started, collapse sheet to min. If stopped, restore preferred size.
    if (oldWidget.isRerouting != widget.isRerouting) {
      if (widget.isRerouting) {
        debugPrint(
            '[FavoriteWidget] didUpdateWidget: rerouting started -> collapsing');
        _safeAnimateSheetTo(_sheetMinChildSize,
            duration: const Duration(milliseconds: 300));
      } else {
        debugPrint(
            '[FavoriteWidget] didUpdateWidget: rerouting stopped -> restoring');
        _safeAnimateSheetTo(_sheetDefaultInitial,
            duration: const Duration(milliseconds: 250));
      }
    }

    // If controller instance changed, swap safely (keep listener attached)
    if (oldWidget.controller != widget.controller) {
      if (_controllerListener != null) {
        try {
          _draggableController.removeListener(_controllerListener!);
        } catch (_) {}
      }

      if (widget.controller != null) {
        try {
          if (widget.controller!.isAttached) {
            _draggableController = DraggableScrollableController();
            _createdControllerLocally = true;
          } else {
            _draggableController = widget.controller!;
            _createdControllerLocally = false;
          }
        } catch (_) {
          _draggableController = DraggableScrollableController();
          _createdControllerLocally = true;
        }
      } else {
        _draggableController = DraggableScrollableController();
        _createdControllerLocally = true;
      }

      if (_controllerListener != null) {
        _draggableController.addListener(_controllerListener!);
      }
    }
  }

  @override
  void dispose() {
    if (_controllerListener != null) {
      try {
        _draggableController.removeListener(_controllerListener!);
      } catch (_) {}
      _controllerListener = null;
    }
    // only dispose if we created it
    if (_createdControllerLocally) {
      try {
        _draggableController.dispose();
      } catch (_) {}
    }
    super.dispose();
  }

  // CORRECTED: Remove from favorites method
  void _removeFromFavorites(Place place) {
    debugPrint(
        'Removing place ${place.name} from favorites - deleting from Firestore');

    // Use the new event that deletes from Firestore
    context
        .read<PlaceBloc>()
        .add(ToggleFavoriteWithDeletionEvent(place: place));

    // Show a snackbar for user feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('removed_from_favorites'.tr()),
        duration: Duration(seconds: 2),
        action: SnackBarAction(
          label: 'undo'.tr(),
          onPressed: () {
            // Note: Undo would need to re-add the place to Firestore
            // This is more complex since we deleted it
            debugPrint('Undo not implemented for deletion');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    const Duration _svcAnimDur = Duration(milliseconds: 220);

    // match SafetyAssist: subtle translate when fading
    final double translateY = (1 - _serviceAreaFactor) * 20;

    return BlocListener<PlaceBloc, PlaceState>(
      listener: (context, state) {
        // Listen for state changes to update UI immediately
        if (state is PlaceFavoriteToggled) {
          // The favorite was toggled - we can show a snackbar or just let the UI update
          debugPrint(
              'Favorite toggled: ${state.place.name} -> ${state.isFavorite}');
        }
      },
      child: DraggableScrollableSheet(
        controller: _draggableController,
        expand: true,
        initialChildSize: _sheetDefaultInitial,
        minChildSize: _sheetMinChildSize,
        maxChildSize: _sheetMaxChildSize,
        builder: (BuildContext context, ScrollController scrollController) {
          // mark sheet as attached and apply any pending animation (once)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_sheetAttached) {
              _sheetAttached = true;
              debugPrint(
                  '[FavoriteWidget] sheet attached (builder) - applying pending if any (pending=$_pendingAnimateTarget)');
              if (_pendingAnimateTarget != null) {
                final t = _pendingAnimateTarget!;
                final d = _pendingAnimateDuration;
                final c = _pendingAnimateCurve;
                _pendingAnimateTarget = null;
                Future.microtask(() async {
                  if (!mounted) {
                    debugPrint(
                        '[FavoriteWidget] skipping pending animate — widget not mounted');
                    return;
                  }
                  try {
                    debugPrint(
                        '[FavoriteWidget] applying pending animateTo($t)');
                    await _draggableController.animateTo(t,
                        duration: d, curve: c);
                    double after = 0;
                    try {
                      after = _draggableController.size;
                    } catch (_) {}
                    debugPrint(
                        '[FavoriteWidget] applied pending animateTo($t) -> controller.size=$after');
                  } catch (e, st) {
                    debugPrint(
                        '[FavoriteWidget] pending animate failed: $e\n$st');
                  }
                });
              }
            }
          });

          return Column(
            children: [
              // --- SERVICE AREA ---
              RepaintBoundary(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _serviceAreaFactor,
                    child: Opacity(
                      opacity: _serviceAreaFactor,
                      child: Transform.translate(
                        offset: Offset(0, translateY),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            // ignore pointer when almost hidden
                            IgnorePointer(
                              ignoring: _serviceAreaFactor < 0.05,
                              child: ServiceButtons(
                                onButtonPressed:
                                    widget.onServiceButtonPressed ?? (label) {},
                                currentLocation: widget.currentLocation,
                                onMapViewPressed: () async {
                                  debugPrint(
                                      '[FavoriteWidget] ServiceButtons.onMapViewPressed tapped (mapSheetOpening=$_mapSheetOpening)');
                                  if (_mapSheetOpening) {
                                    debugPrint(
                                        '[FavoriteWidget] ignoring map tap - already opening');
                                    return;
                                  }
                                  _mapSheetOpening = true;
                                  try {
                                    await widget.onMapViewPressed?.call();
                                  } finally {
                                    await Future.delayed(
                                        const Duration(milliseconds: 200));
                                    _mapSheetOpening = false;
                                    debugPrint(
                                        '[FavoriteWidget] mapSheetOpening reset to false');
                                  }
                                },
                                onCenterPressed: () async {
                                  debugPrint(
                                      '[FavoriteWidget] ServiceButtons.onCenterPressed tapped');
                                  // collapse sheet to min first
                                  try {
                                    await _safeAnimateSheetTo(
                                        _sheetMinChildSize,
                                        duration:
                                            const Duration(milliseconds: 260));
                                  } catch (e, st) {
                                    debugPrint(
                                        '[FavoriteWidget] safeAnimateSheetTo failed before center: $e\n$st');
                                  }

                                  try {
                                    widget.onCenterPressed?.call();
                                  } catch (e, st) {
                                    debugPrint(
                                        '[FavoriteWidget] onCenterPressed threw: $e\n$st');
                                  }

                                  if (widget.onShowMyInfoPressed != null) {
                                    try {
                                      await widget.onShowMyInfoPressed!.call();
                                    } catch (e, st) {
                                      debugPrint(
                                          '[FavoriteWidget] onShowMyInfoPressed threw: $e\n$st');
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- main sheet content (white container) ---
              Expanded(
                // use padding with top = MediaQuery padding when sheet is at top
                child: Padding(
                  padding: EdgeInsets.only(
                      top: _isAtTop ? MediaQuery.of(context).padding.top : 0),
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
                          blurRadius: 0.5,
                          offset: Offset(-1, 0),
                        ),
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 0.5,
                          offset: Offset(1, 0),
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
                                        (item) => item["title"] == newCategory);

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

                            // FAVORITES SECTION
                            BlocBuilder<PlaceBloc, PlaceState>(
                              builder: (context, state) {
                                List<Place> favoritePlaces = [];
                                bool isLoading = state is PlaceOperationLoading;

                                if (state is PlacesLoaded) {
                                  // Always show favorites from the loaded places
                                  favoritePlaces = state.places
                                      .where((place) => place.isFavorite)
                                      .toList();
                                }

                                return Column(
                                  children: [
                                    // Favorites List Tile
                                    ListTile(
                                      leading: Icon(
                                        Icons.favorite,
                                        color: const Color(0xFF6750A4),
                                      ),
                                      title: Text(
                                        "favorites".tr(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "private_places".tr(args: [
                                          favoritePlaces.length.toString()
                                        ]),
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          lists[0]['expanded']
                                              ? Icons.keyboard_arrow_up
                                              : Icons.keyboard_arrow_down,
                                          color: Colors.grey.shade600,
                                        ),
                                        onPressed: () => toggleExpansion(0),
                                      ),
                                      onTap: () => toggleExpansion(0),
                                    ),

                                    // Expanded Favorites List
                                    if (lists[0]['expanded'])
                                      Column(
                                        children: [
                                          if (isLoading)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child:
                                                  CircularProgressIndicator(),
                                            )
                                          else if (favoritePlaces.isEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Text(
                                                "no_favorites".tr(),
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            )
                                          else
                                            ...favoritePlaces
                                                .map((Place place) {
                                              return ListTile(
                                                leading: Icon(
                                                  Icons.favorite,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                title: Text(
                                                  place.name,
                                                  style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                ),
                                                subtitle: place.address != null
                                                    ? Text(
                                                        place.address!,
                                                        style: TextStyle(
                                                          color: isDarkMode
                                                              ? Colors.white70
                                                              : Colors
                                                                  .grey[600],
                                                          fontSize: 12,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      )
                                                    : null,
                                                trailing:
                                                    PopupMenuButton<String>(
                                                  icon: const Icon(
                                                      Icons.more_vert,
                                                      color: Colors.grey),
                                                  onSelected: (value) {
                                                    if (value == 'show') {
                                                      widget.onShowPlace
                                                          ?.call(place);
                                                    } else if (value ==
                                                        'remove') {
                                                      _removeFromFavorites(
                                                          place);
                                                    }
                                                  },
                                                  itemBuilder: (BuildContext
                                                          context) =>
                                                      <PopupMenuEntry<String>>[
                                                    PopupMenuItem<String>(
                                                      value: 'show',
                                                      child: Text(
                                                          "show_on_map".tr()),
                                                    ),
                                                    PopupMenuItem<String>(
                                                      value: 'remove',
                                                      child: Text(
                                                          "remove_from_favorites"
                                                              .tr()),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                        ],
                                      ),

                                    const Divider(
                                        indent: 16, endIndent: 16, height: 0),
                                  ],
                                );
                              },
                            ),

                            // OTHER CATEGORIES (want_to_go, visited)
                            ...List.generate(lists.length - 1, (index) {
                              final categoryIndex =
                                  index + 1; // Skip favorites (index 0)
                              final String categoryKey =
                                  lists[categoryIndex]['title'];
                              return BlocBuilder<PlaceBloc, PlaceState>(
                                builder: (context, state) {
                                  List<Place> categoryPlaces = [];
                                  int count = 0;

                                  if (state is PlacesLoaded) {
                                    // For other categories, filter by category field
                                    categoryPlaces = state.places
                                        .where((place) =>
                                            place.category == categoryKey)
                                        .toList();
                                    count = categoryPlaces.length;
                                  }

                                  return Column(
                                    children: [
                                      ListTile(
                                        leading: Icon(
                                          lists[categoryIndex]["icon"],
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
                                            lists[categoryIndex]['expanded']
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            color: Colors.grey.shade600,
                                          ),
                                          onPressed: () =>
                                              toggleExpansion(categoryIndex),
                                        ),
                                        onTap: () =>
                                            toggleExpansion(categoryIndex),
                                      ),
                                      if (lists[categoryIndex]['expanded'] &&
                                          state is PlacesLoaded)
                                        Column(
                                          children:
                                              categoryPlaces.map((Place place) {
                                            return ListTile(
                                              title: Text(
                                                place.name,
                                                style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                              subtitle: place.address != null
                                                  ? Text(
                                                      place.address!,
                                                      style: TextStyle(
                                                        color: isDarkMode
                                                            ? Colors.white70
                                                            : Colors.grey[600],
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    )
                                                  : null,
                                              trailing: PopupMenuButton<String>(
                                                icon: const Icon(
                                                    Icons.more_vert,
                                                    color: Colors.grey),
                                                onSelected: (value) {
                                                  if (value == 'show') {
                                                    widget.onShowPlace
                                                        ?.call(place);
                                                  } else if (value ==
                                                      'remove') {
                                                    // Remove from custom category
                                                    context
                                                        .read<PlaceBloc>()
                                                        .add(
                                                          UpdatePlaceCategoryEvent(
                                                            placeId: place.id,
                                                            newCategory: 'none',
                                                          ),
                                                        );
                                                    // Refresh the list after a short delay
                                                    Future.delayed(
                                                        const Duration(
                                                            milliseconds: 500),
                                                        () {
                                                      context.read<PlaceBloc>().add(
                                                          const GetAllPlacesEvent());
                                                    });
                                                  }
                                                },
                                                itemBuilder: (BuildContext
                                                        context) =>
                                                    <PopupMenuEntry<String>>[
                                                  PopupMenuItem<String>(
                                                    value: 'show',
                                                    child: Text(
                                                        "show_on_map".tr()),
                                                  ),
                                                  PopupMenuItem<String>(
                                                    value: 'remove',
                                                    child: Text(
                                                        "remove_from_list"
                                                            .tr()),
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
      ),
    );
  }
}
