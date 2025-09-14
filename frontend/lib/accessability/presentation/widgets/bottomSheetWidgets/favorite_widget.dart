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
    {"icon": Icons.favorite_border, "title": "favorites", "expanded": false},
    {"icon": Icons.outlined_flag, "title": "want_to_go", "expanded": false},
    {"icon": Icons.navigation_outlined, "title": "visited", "expanded": false},
  ];

  // Draggable sheet controller + expansion state (copied from LocationWidgets)
  late final DraggableScrollableController _draggableController;
  bool _isExpanded = false;
  late final double _expandThreshold = 0.8;
  VoidCallback? _controllerListener;

  // sheet sizing constants (keep consistent with build)
  final double _sheetMinChildSize = 0.15;
  final double _preferredInitialSize = 0.5;
  final double _sheetMaxChildSize = 1.0;
  bool _isAtTop = false;

  // attachment / pending animation helpers (copied pattern from LocationWidgets)
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
      context.read<PlaceBloc>().add(const GetAllPlacesEvent());
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[FavoriteWidget] initState (isRerouting=${widget.isRerouting})');

    // choose whether to reuse passed controller or create our own (safe if already attached)
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

    // attach listener to keep _isExpanded in sync with controller.size
    _controllerListener = () {
      try {
        final size = _draggableController.size;
        final expanded = size >= _expandThreshold;
        final atTop = size >= 0.995; // treat ~1.0 as 'at top'
        debugPrint(
            '[FavoriteWidget] controller.size=$size expanded=$expanded _isExpanded=$_isExpanded _isAtTop=$_isAtTop isAttached=${_draggableController.isAttached}');
        if (expanded != _isExpanded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (expanded != _isExpanded) {
              debugPrint('[FavoriteWidget] updating _isExpanded -> $expanded');
              setState(() => _isExpanded = expanded);
            }
          });
        }
        // update at-top state so widgets that depend on it can react
        if (atTop != (_isAtTop ?? false)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _isAtTop = atTop);
          });
        }
      } catch (e, st) {
        debugPrint('[FavoriteWidget] controller listener error: $e\n$st');
      }
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
        _safeAnimateSheetTo(_preferredInitialSize,
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

  // ----------------- _safeAnimateSheetTo (replace your existing) -----------------
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
        // after animate, log reported size
        double after = 0;
        try {
          after = _draggableController.size;
        } catch (_) {}
        debugPrint(
            '[FavoriteWidget] animateTo completed to $target, controller.size=$after');
      } catch (e, st) {
        debugPrint('[FavoriteWidget] animateTo failed: $e\n$st');
        // try to print current size even on failure
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

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      controller: _draggableController,
      expand: true,
      initialChildSize: _preferredInitialSize,
      minChildSize: _sheetMinChildSize,
      maxChildSize: _sheetMaxChildSize,
      builder: (BuildContext context, ScrollController scrollController) {
        // mark sheet as attached and apply any pending animation (once)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_sheetAttached) {
            _sheetAttached = true;
            debugPrint(
                '[FavoriteWidget] sheet attached (builder) - applying pending if any (pending=$_pendingAnimateTarget) isAttached=${_draggableController.isAttached}');
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
                      '[FavoriteWidget] applying pending animateTo($t) (isAttached=${_draggableController.isAttached})');
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

        // NOTE: ServiceButtons is placed OUTSIDE the white container below (same visual position as LocationWidgets)
        return Column(
          children: [
            const SizedBox(height: 8),

            // --- OUTSIDE ServiceButtons (above the main container) ---
            IgnorePointer(
              // now also ignore if rerouting is active
              ignoring: _isExpanded || widget.isRerouting,
              child: Builder(builder: (ctx) {
                // show/hide with animation like LocationWidgets
                final showButtons = !(_isExpanded || widget.isRerouting);
                return AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    opacity: (_isExpanded || widget.isRerouting) ? 0.0 : 1.0,
                    // keep same children so callbacks remain unchanged; use SizedBox.shrink when hidden so size collapses
                    child: showButtons
                        ? ServiceButtons(
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
                              final currentLoc = widget.currentLocation;
                              if (currentLoc == null) {
                                debugPrint(
                                    '[FavoriteWidget] no currentLocation to center on');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('locationNotAvailable'.tr())),
                                );
                                return;
                              }

                              // collapse sheet to min first
                              try {
                                debugPrint(
                                    '[FavoriteWidget] collapsing sheet to min before center');
                                await _safeAnimateSheetTo(_sheetMinChildSize,
                                    duration:
                                        const Duration(milliseconds: 260));
                              } catch (e, st) {
                                debugPrint(
                                    '[FavoriteWidget] safeAnimateSheetTo failed before center: $e\n$st');
                              }

                              // call any center handler
                              try {
                                widget.onCenterPressed?.call();
                              } catch (e, st) {
                                debugPrint(
                                    '[FavoriteWidget] onCenterPressed threw: $e\n$st');
                              }

                              // then request host to show my-info overlay if provided
                              if (widget.onShowMyInfoPressed != null) {
                                try {
                                  debugPrint(
                                      '[FavoriteWidget] calling onShowMyInfoPressed');
                                  await widget.onShowMyInfoPressed!.call();
                                } catch (e, st) {
                                  debugPrint(
                                      '[FavoriteWidget] onShowMyInfoPressed threw: $e\n$st');
                                }
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
