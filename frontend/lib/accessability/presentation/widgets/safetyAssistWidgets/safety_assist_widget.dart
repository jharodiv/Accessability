// lib/presentation/widgets/bottomSheetWidgets/safety_assist_widget.dart

import 'package:accessability/accessability/presentation/widgets/safetyAssistWidgets/add_emergency_contact.dart';
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
  final double _sheetMinChildSize = 0.3;
  final double _sheetHelperExpandedSize = 0.8;
  final double _sheetDefaultInitial = 0.5;
  final double _expandThreshold = 0.8;

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

    // attach listener to draggable controller to update _isExpanded/_isAtTop
    _controllerListener = () {
      try {
        final size = _draggableController.size;
        final expanded =
            size >= _expandThreshold; // same threshold used previously
        final atTop = size >= 0.995; // treat ~1.0 as 'at top'
        if (expanded != _isExpanded) setState(() => _isExpanded = expanded);
        if (atTop != _isAtTop) setState(() => _isAtTop = atTop);
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

  // void _showEmergencyServicesWidget() {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //     ),
  //     builder: (context) {
  //       return SafeArea(
  //         child: Padding(
  //           padding: EdgeInsets.only(
  //             bottom: MediaQuery.of(context).viewInsets.bottom,
  //           ),
  //           // Wrap in SizedBox to control height inside your DraggableScrollableSheet
  //           child: SizedBox(
  //             height: MediaQuery.of(context).size.height * 0.85,
  //             child: const SafetyAssistEmergencyServices(),
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

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

  void _openEmergencyContactsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              // limit height so list fits above keyboard if needed
              height: MediaQuery.of(context).size.height * 0.6,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                    ),
                    Text(
                      'emergency_services'.tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    Expanded(
                      child: BlocBuilder<EmergencyBloc, EmergencyState>(
                        builder: (context, state) {
                          final List<Widget> tiles = [];

                          if (state is EmergencyContactsLoaded &&
                              state.contacts.isNotEmpty) {
                            tiles.add(
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6.0),
                                child: Text(
                                  'my_contacts'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            );

                            for (final contact in state.contacts) {
                              tiles.add(
                                ListTile(
                                  leading: const CircleAvatar(
                                      child: Icon(Icons.person)),
                                  title: Text(contact.name),
                                  subtitle: Text(contact.location),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.call),
                                        onPressed: () {
                                          final number =
                                              contact.update?.isNotEmpty == true
                                                  ? contact.update
                                                  : null;
                                          if (widget
                                                  .onEmergencyServicePressed !=
                                              null) {
                                            widget.onEmergencyServicePressed!(
                                                contact.name, number);
                                          } else if (number != null) {
                                            _launchCaller(number);
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  'no_number_available'.tr()),
                                            ));
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.message),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                'implement_message_action'
                                                    .tr()),
                                          ));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              tiles.add(const Divider());
                            }
                          }

                          // Common services header
                          tiles.add(
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6.0),
                              child: Text(
                                'common_services'.tr(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          );

                          for (final svc in _defaultServices) {
                            tiles.add(
                              ListTile(
                                leading: const CircleAvatar(
                                    child: Icon(Icons.local_hospital)),
                                title: Text(svc['label'] ?? ''),
                                subtitle: Text(
                                    svc['number'] ?? 'no_number_added'.tr()),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.call),
                                      onPressed: () {
                                        if (widget.onEmergencyServicePressed !=
                                            null) {
                                          widget.onEmergencyServicePressed!(
                                              svc['label']!, svc['number']);
                                        } else if (svc['number'] != null &&
                                            svc['number']!.isNotEmpty) {
                                          _launchCaller(svc['number']!);
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                'no_number_available'.tr()),
                                          ));
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.info_outline),
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                              content: Text('${svc['label']}')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                            tiles.add(const Divider());
                          }

                          return ListView(
                            padding: EdgeInsets.zero,
                            children: tiles,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    return DraggableScrollableSheet(
      controller: _draggableController,
      // Use different initial sizes based on whether the helper is showing.
      initialChildSize: _showHelper ? 0.8 : 0.5,
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
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: _isExpanded || _showHelper || widget.isRerouting,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: (_isExpanded || _showHelper || widget.isRerouting)
                    ? 0.0
                    : 1.0,
                child: ServiceButtons(
                  onButtonPressed: widget.onServiceButtonPressed ?? (label) {},
                  currentLocation: widget.currentLocation,
                  onMapViewPressed: widget.onMapViewPressed,
                  onCenterPressed: () {
                    // fire-and-forget, _handleCenterPressed is async
                    _handleCenterPressed();
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
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
                                height: 2,
                                color: Colors.grey.shade700,
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
                                    crossAxisAlignment: CrossAxisAlignment.end,
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
                                    BlocProvider.of<EmergencyBloc>(context).add(
                                      FetchEmergencyContactsEvent(
                                          uid: widget.uid),
                                    );
                                  }
                                },
                                builder: (context, state) {
                                  if (state is EmergencyLoading) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  } else if (state is EmergencyContactsLoaded) {
                                    final contacts = state.contacts;
                                    if (contacts.isEmpty) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                          "no_emergency_contacts".tr(),
                                          style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }
                                    return Column(
                                      children: contacts.map((contact) {
                                        return Column(
                                          children: [
                                            // Updated tile design to match emergency services
                                            Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDarkMode
                                                    ? Colors.grey[800]
                                                    : Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                  backgroundColor:
                                                      const Color(0xFF6750A4),
                                                  child: Text(
                                                    contact.name.isNotEmpty
                                                        ? contact.name[0]
                                                            .toUpperCase()
                                                        : '?',
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                                title: Text(
                                                  contact.name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                ),
                                                subtitle: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (contact
                                                        .location.isNotEmpty)
                                                      Text(
                                                        contact.location,
                                                        style: TextStyle(
                                                          color: isDarkMode
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                  .grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    if (contact
                                                        .arrival.isNotEmpty)
                                                      Text(
                                                        contact.arrival,
                                                        style: TextStyle(
                                                          color: isDarkMode
                                                              ? Colors.grey[400]
                                                              : Colors
                                                                  .grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    Text(
                                                      contact.update,
                                                      style: TextStyle(
                                                        color: isDarkMode
                                                            ? Colors.grey[400]
                                                            : Colors.grey[600],
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      icon: Icon(Icons.call,
                                                          color: isDarkMode
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF6750A4),
                                                          size: 20),
                                                      onPressed: () {
                                                        final number = contact
                                                                .update
                                                                .isNotEmpty
                                                            ? contact.update
                                                            : null;
                                                        if (number != null) {
                                                          _launchCaller(number);
                                                        } else {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                                content: Text(
                                                                    'no_number_available'
                                                                        .tr())),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.delete,
                                                          color: Colors.red,
                                                          size: 20),
                                                      onPressed: () {
                                                        if (contact.id !=
                                                            null) {
                                                          BlocProvider.of<
                                                                      EmergencyBloc>(
                                                                  context)
                                                              .add(
                                                            DeleteEmergencyContactEvent(
                                                              uid: widget.uid,
                                                              contactId:
                                                                  contact.id!,
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const Divider(height: 1),
                                          ],
                                        );
                                      }).toList(),
                                    );
                                  } else if (state is EmergencyOperationError) {
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
          ],
        );
      },
    );
  }
}
