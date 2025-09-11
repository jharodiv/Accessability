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

  // New optional callback to override emergency service action.
  // (label, phoneNumber)
  final void Function(String label, String? number)? onEmergencyServicePressed;

  const SafetyAssistWidget({
    Key? key,
    required this.uid,
    this.currentLocation,
    this.onMapViewPressed,
    this.onCenterPressed,
    this.onServiceButtonPressed,
    this.locationHandler,
    this.onEmergencyServicePressed,
  }) : super(key: key);

  @override
  State<SafetyAssistWidget> createState() => _SafetyAssistWidgetState();
}

class _SafetyAssistWidgetState extends State<SafetyAssistWidget> {
  // Boolean state variable to determine which design to display
  bool _showHelper = false;

  // Add a controller for the DraggableScrollableSheet.
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  // Tracks whether sheet is expanded so we can fade/disable service buttons
  bool _isExpanded = false;
  bool _isAtTop = false;

  // store listener so we can remove it on dispose
  VoidCallback? _controllerListener;

  @override
  void initState() {
    super.initState();

    // fetch emergency contacts
    BlocProvider.of<EmergencyBloc>(context)
        .add(FetchEmergencyContactsEvent(uid: widget.uid));

    // attach listener to draggable controller to update _isExpanded
    _controllerListener = () {
      try {
        final size = _draggableController.size;
        final expanded = size >= 0.8;
        final atTop = size >= 0.995; // treat ~1.0 as 'at top'
        if (expanded != _isExpanded) setState(() => _isExpanded = expanded);
        if (atTop != _isAtTop) setState(() => _isAtTop = atTop);
      } catch (_) {}
    };

    _draggableController.addListener(_controllerListener!);
  }

  @override
  void dispose() {
    if (_controllerListener != null) {
      _draggableController.removeListener(_controllerListener!);
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
  void _handleCenterPressed() {
    if (widget.onCenterPressed != null) {
      widget.onCenterPressed!();
      return;
    }
    if (widget.locationHandler != null &&
        widget.locationHandler!.currentLocation != null) {
      try {
        widget.locationHandler!
            .panCameraToLocation(widget.locationHandler!.currentLocation!);
      } catch (e) {
        // fallback to snackbar if pan fails
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('locationNotAvailable'.tr())),
    );
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
      minChildSize: 0.5,
      maxChildSize: 1.0, // <- allow dragging to utmost top
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: _isExpanded || _showHelper,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: (_isExpanded || _showHelper) ? 0.0 : 1.0,
                child: ServiceButtons(
                  onButtonPressed: widget.onServiceButtonPressed ?? (label) {},
                  currentLocation: widget.currentLocation,
                  onMapViewPressed: widget.onMapViewPressed,
                  onCenterPressed: widget.onCenterPressed ?? () {},
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
                              BlocBuilder<EmergencyBloc, EmergencyState>(
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
                                          ),
                                        ),
                                      );
                                    }
                                    return Column(
                                      children: contacts.map((contact) {
                                        return Column(
                                          children: [
                                            ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: Colors.grey,
                                                child: Icon(Icons.person,
                                                    color: Colors.white),
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
                                                  Text(
                                                    contact.location,
                                                    style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    contact.arrival,
                                                    style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                  Text(
                                                    contact.update,
                                                    style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.call,
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF6750A4)),
                                                    onPressed: () {
                                                      final number = contact
                                                                  .update
                                                                  ?.isNotEmpty ==
                                                              true
                                                          ? contact.update
                                                          : null;
                                                      if (widget
                                                              .onEmergencyServicePressed !=
                                                          null) {
                                                        widget.onEmergencyServicePressed!(
                                                            contact.name,
                                                            number);
                                                      } else if (number !=
                                                          null) {
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
                                                    icon: Icon(Icons.message,
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF6750A4)),
                                                    onPressed: () {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                'implement_message_action'
                                                                    .tr())),
                                                      );
                                                    },
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red),
                                                    onPressed: () {
                                                      if (contact.id != null) {
                                                        BlocProvider.of<
                                                                    EmergencyBloc>(
                                                                context)
                                                            .add(
                                                                DeleteEmergencyContactEvent(
                                                          uid: widget.uid,
                                                          contactId:
                                                              contact.id!,
                                                        ));
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(),
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
