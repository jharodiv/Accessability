// lib/presentation/widgets/bottomSheetWidgets/safety_assist_widget.dart

import 'package:accessability/accessability/presentation/widgets/safetyAssistWidgets/add_emergency_contact.dart';
import 'package:accessability/accessability/presentation/widgets/safetyAssistWidgets/emergency_contact_list.dart';
import 'package:accessability/accessability/presentation/widgets/safetyAssistWidgets/safety_assist_emergency_services.dart';
import 'package:accessability/accessability/presentation/widgets/safetyAssistWidgets/safety_assist_helper_widget.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/service_buttons.dart';
import 'package:accessability/accessability/presentation/screens/gpsscreen/location_handler.dart';
import 'package:accessability/accessability/data/model/emergency_contact.dart';
import 'package:accessability/accessability/logic/bloc/emergency/bloc/emergency_bloc.dart';
import 'package:accessability/accessability/logic/bloc/emergency/bloc/emergency_event.dart';
import 'package:accessability/accessability/logic/bloc/emergency/bloc/emergency_state.dart';
import 'package:accessability/accessability/themes/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyAssistWidget extends StatefulWidget {
  final String uid;

  // NEW optional params so ServiceButtons can behave like in LocationWidgets
  final LatLng? currentLocation;
  final Future<void> Function()? onMapViewPressed;
  final VoidCallback? onCenterPressed;
  final void Function(String)? onServiceButtonPressed;
  final LocationHandler? locationHandler;
  final Future<void> Function()? onShowMyInfoPressed;
  final DraggableScrollableController? controller; // <-- ADD

  // New optional callback to override emergency service action.
  // (label, phoneNumber)
  final void Function(String label, String? number)? onEmergencyServicePressed;

  final bool isRerouting; // <-- ADD

  const SafetyAssistWidget({
    Key? key,
    required this.uid,
    this.currentLocation,
    this.onMapViewPressed,
    this.onCenterPressed,
    this.onServiceButtonPressed,
    this.locationHandler,
    this.onEmergencyServicePressed,
    this.controller, // <- add this
    this.onShowMyInfoPressed, // <- add this
    this.isRerouting = false, // <- add this default
  }) : super(key: key);

  @override
  State<SafetyAssistWidget> createState() => _SafetyAssistWidgetState();
}

class _SafetyAssistWidgetState extends State<SafetyAssistWidget> {
  // Boolean state variable to determine which design to display
  bool _showHelper = false;

  // Add a controller for the DraggableScrollableSheet.
  late final DraggableScrollableController _draggableController;

  // Tracks whether sheet is expanded so we can fade/disable service buttons
  bool _isExpanded = false;
  bool _isAtTop = false;

  // store listener so we can remove it on dispose
  VoidCallback? _controllerListener;
  bool _createdControllerLocally = false;
  bool _sheetAttached = false;
  double? _pendingAnimateTarget;
  Duration _pendingAnimateDuration = const Duration(milliseconds: 300);
  Curve _pendingAnimateCurve = Curves.easeOut;

// sizing constants (keep consistent with build)
  final double _sheetMinChildSize = 0.30;
  final double _sheetHelperExpandedSize = 0.8;
  // reduce initial so you can see the disappearance more clearly
  final double _sheetDefaultInitial = 0.35;
  final double _expandThreshold = 0.8;
  double _serviceAreaFactor = 1.0;

  // SINGLE source-of-truth for whether service buttons are shown
  bool _serviceVisible = true;

  @override
  void initState() {
    super.initState();

    // fetch emergency contacts
    BlocProvider.of<EmergencyBloc>(context)
        .add(FetchEmergencyContactsEvent(uid: widget.uid));

    // choose whether to reuse passed controller or create our own (safe if already attached)
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

    const double _hideThreshold = 0.55;
    final double _fadeStart = _sheetDefaultInitial; // e.g. 0.35
    // how sensitive to changes before triggering setState (increase to reduce rebuilds)
    const double _factorDirtyThreshold = 0.02;

    _controllerListener = () {
      try {
        final size = _draggableController.size;

        // compute top state (avoid status bar overlap when at very top)
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

        // Only call setState when either the factor moved enough OR atTop changed
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
          // ignore if animateTo not available yet or controller not attached
        }
      });
    }
  }

  Future<void> _safeAnimateSheetTo(double target,
      {Duration duration = const Duration(milliseconds: 300),
      Curve curve = Curves.easeOut}) async {
    if (!mounted) return;

    // If sheet is attached, animate immediately (guarded)
    if (_sheetAttached) {
      try {
        await _draggableController.animateTo(target,
            duration: duration, curve: curve);
      } catch (e, st) {
        debugPrint('[SafetyAssistWidget] animateTo failed: $e\n$st');
      }
      return;
    }

    // queue it to run once sheet attaches
    _pendingAnimateTarget = target;
    _pendingAnimateDuration = duration;
    _pendingAnimateCurve = curve;
    debugPrint(
        '[SafetyAssistWidget] queued animateTo($target) — sheet not attached yet');
  }

  @override
  void didUpdateWidget(covariant SafetyAssistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If rerouting started, collapse sheet to min. If stopped, restore preferred size.
    if (oldWidget.isRerouting != widget.isRerouting) {
      if (widget.isRerouting) {
        _safeAnimateSheetTo(_sheetMinChildSize,
            duration: const Duration(milliseconds: 300));
      } else {
        _safeAnimateSheetTo(_sheetDefaultInitial,
            duration: const Duration(milliseconds: 250));
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
    // only dispose when we created the controller locally
    if (_createdControllerLocally) {
      try {
        _draggableController.dispose();
      } catch (_) {}
    }
    super.dispose();
  }

  void _showEmergencyServicesWidget() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const SafetyAssistEmergencyServices(),
      ),
    );
  }

  void _showAddEmergencyContactDialog() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => AddEmergencyContactScreen(uid: widget.uid),
        fullscreenDialog: true, // optional: shows iOS-style modal animation
      ),
    )
        .then((result) {
      if (result is Map<String, String?>) {
        final contact = EmergencyContact(
          name: result['name'] ?? '',
          location: result['location'] ?? '',
          arrival: result['arrival'] ?? '',
          update: result['phone'] ?? '',
        );
        BlocProvider.of<EmergencyBloc>(context).add(
          AddEmergencyContactEvent(uid: widget.uid, contact: contact),
        );
      }
    });
  }

  // default center action: prefer explicit callback, then LocationHandler, else snackbar
  // default center action: prefer explicit callback, then LocationHandler, else snackbar
  Future<void> _handleCenterPressed() async {
    if (widget.onCenterPressed != null) {
      try {
        widget.onCenterPressed!();
      } catch (e, st) {
        debugPrint('onCenterPressed threw: $e\n$st');
      }
    } else if (widget.locationHandler != null &&
        widget.locationHandler!.currentLocation != null) {
      try {
        widget.locationHandler!
            .panCameraToLocation(widget.locationHandler!.currentLocation!);
      } catch (e) {
        // fallback to snackbar if pan fails
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('locationNotAvailable'.tr())),
      );
    }

    // AFTER centering, ask the host to show my-info overlay if provided
    if (widget.onShowMyInfoPressed != null) {
      try {
        await widget.onShowMyInfoPressed!();
      } catch (e, st) {
        debugPrint('onShowMyInfoPressed threw: $e\n$st');
      }
    }
  }

  // Launch phone dialer using url_launcher
  Future<void> _launchCaller(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (!await launchUrl(uri)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('cannot_launch_phone'.tr())),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // Default emergency services list (fill with numbers valid in your region).
  // I used 911 as a generic emergency number — replace with local numbers if needed.
  final List<Map<String, String?>> _defaultServices = [
    {'label': 'Police', 'number': '911'},
    {'label': 'Ambulance', 'number': '911'},
    {'label': 'Fire Department', 'number': '911'},
    // Add more if you want, eg local hotline
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final bool serviceVisible = _serviceVisible;
    const Duration _svcAnimDur = Duration(milliseconds: 220);

    final double downPx = serviceVisible ? 0.0 : 40.0; // px to slide down
    final double translateY =
        (1 - _serviceAreaFactor) * 20; // smaller value for subtler movement

    return DraggableScrollableSheet(
      controller: _draggableController,
      // Use different initial sizes based on whether the helper is showing.
      initialChildSize:
          _showHelper ? _sheetHelperExpandedSize : _sheetDefaultInitial,
      expand: true,
      minChildSize: 0.3,
      maxChildSize: 1.0, // <- allow dragging to utmost top
      builder: (BuildContext context, ScrollController scrollController) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_sheetAttached) {
            _sheetAttached = true;

            // if there is a pending animation, run it once now
            if (_pendingAnimateTarget != null) {
              final t = _pendingAnimateTarget!;
              final d = _pendingAnimateDuration;
              final c = _pendingAnimateCurve;
              _pendingAnimateTarget = null;
              Future.microtask(() async {
                if (!mounted) return;
                try {
                  await _draggableController.animateTo(t,
                      duration: d, curve: c);
                  debugPrint(
                      '[SafetyAssistWidget] applied pending animateTo($t)');
                } catch (e, st) {
                  debugPrint(
                      '[SafetyAssistWidget] pending animate failed: $e\n$st');
                }
              });
            }
          }
        });

        return Column(
          children: [
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
                          IgnorePointer(
                            ignoring: _serviceAreaFactor < 0.05,
                            child: ServiceButtons(
                              onButtonPressed:
                                  widget.onServiceButtonPressed ?? (label) {},
                              currentLocation: widget.currentLocation,
                              onMapViewPressed: widget.onMapViewPressed,
                              onCenterPressed: () {
                                _handleCenterPressed();
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
            Expanded(
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
                        blurRadius: 0.5, // soft edge
                        offset: Offset(-1, 0), // left side
                      ),
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 0.5,
                        offset: Offset(1, 0), // right side
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      // Toggle between the helper widget and the main design.
                      child: _showHelper
                          ? SafetyAssistHelperWidget(
                              onBack: () {
                                setState(() {
                                  _showHelper = false;
                                });
                                try {
                                  _draggableController.animateTo(
                                    0.8, // Collapse back to 80% of the screen.
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                } catch (_) {
                                  // ignore if animateTo not available on older Flutter
                                }
                              },
                            )
                          : Column(
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
                                const SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "safety_assist".tr(),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Row(
                                      // contains emergency button + help icon
                                      children: [
                                        // Emergency services button (police / ambulance / fire)
                                        GestureDetector(
                                          onTap: _showEmergencyServicesWidget,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8.0),
                                            child: Icon(
                                              Icons.local_police,
                                              color: isDarkMode
                                                  ? Colors.white
                                                  : const Color(0xFF6750A4),
                                            ),
                                          ),
                                        ),
                                        // Help icon toggles the helper widget.
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _showHelper = true;
                                            });
                                            try {
                                              _draggableController.animateTo(
                                                0.8, // Expand the sheet to 80% of the screen.
                                                duration: const Duration(
                                                    milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            } catch (_) {
                                              // ignore on older Flutter versions
                                            }
                                          },
                                          child: Icon(
                                            Icons.help_outline,
                                            color: isDarkMode
                                                ? Colors.white
                                                : const Color(0xFF6750A4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                InkWell(
                                  onTap: _showAddEmergencyContactDialog,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Icon(
                                          Icons.person_add_outlined,
                                          color: isDarkMode
                                              ? Colors.white
                                              : const Color(0xFF6750A4),
                                          size: 30,
                                        ),
                                        const SizedBox(width: 15),
                                        Text(
                                          "add_emergency_contact".tr(),
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(),
                                BlocConsumer<EmergencyBloc, EmergencyState>(
                                  listener: (context, state) {
                                    if (state is EmergencyOperationSuccess) {
                                      // Refresh contacts after any operation
                                      BlocProvider.of<EmergencyBloc>(context)
                                          .add(
                                        FetchEmergencyContactsEvent(
                                            uid: widget.uid),
                                      );
                                    }
                                  },
                                  builder: (context, state) {
                                    if (state is EmergencyLoading) {
                                      return const Center(
                                          child: CircularProgressIndicator());
                                    } else if (state
                                        is EmergencyContactsLoaded) {
                                      return EmergencyContactsList(
                                        contacts: state.contacts,
                                        isDarkMode: isDarkMode,
                                        uid: widget.uid,
                                        onAddPressed:
                                            _showAddEmergencyContactDialog,
                                        onCallPressed: (number) {
                                          if (number != null &&
                                              number.isNotEmpty) {
                                            _launchCaller(number);
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'no_number_available'
                                                          .tr())),
                                            );
                                          }
                                        },
                                        onMessagePressed: (contact) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'implement_message_action'
                                                        .tr())),
                                          );
                                        },
                                        onDeletePressed: (contactId) {
                                          if (contactId != null &&
                                              contactId.isNotEmpty) {
                                            BlocProvider.of<EmergencyBloc>(
                                                    context)
                                                .add(
                                              DeleteEmergencyContactEvent(
                                                  uid: widget.uid,
                                                  contactId: contactId),
                                            );
                                          }
                                        },
                                      );
                                    } else if (state
                                        is EmergencyOperationError) {
                                      return Text(
                                        state.message,
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
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
