import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:accessability/accessability/presentation/widgets/homepageWidgets/bottomWidgetFiles/service_buttons.dart';

typedef ContentBuilder = Widget Function(
    BuildContext context, ScrollController controller);

class SharedBottomPanel extends StatefulWidget {
  final LatLng? currentLocation;
  final bool isJoining;
  final double initialChildSize;
  final VoidCallback? onMapViewPressed;
  final void Function(LatLng)? onCenterPressed;
  final ContentBuilder contentBuilder;

  const SharedBottomPanel({
    Key? key,
    required this.contentBuilder,
    this.currentLocation,
    this.isJoining = false,
    this.initialChildSize = 0.30,
    this.onMapViewPressed,
    this.onCenterPressed,
  }) : super(key: key);

  @override
  State<SharedBottomPanel> createState() => _SharedBottomPanelState();
}

class _SharedBottomPanelState extends State<SharedBottomPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: widget.isJoining ? 1.0 : widget.initialChildSize,
      minChildSize: 0.20,
      maxChildSize: 1.0,
      expand: true,
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            final currentlyExpanded = notification.extent > 0.6;
            if (currentlyExpanded != _isExpanded) {
              setState(() => _isExpanded = currentlyExpanded);
            }
            return false;
          },
          child: Column(
            children: [
              // Top row: service buttons (shared)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isExpanded || widget.isJoining ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _isExpanded,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 8.0),
                    child: ServiceButtons(
                      onButtonPressed: (label) {/* optional */},
                      currentLocation: widget.currentLocation,
                      onMapViewPressed: widget.onMapViewPressed,
                      onCenterPressed: () {
                        if (widget.onCenterPressed != null &&
                            widget.currentLocation != null) {
                          widget.onCenterPressed!(widget.currentLocation!);
                        }
                      },
                    ),
                  ),
                ),
              ),

              // Main draggable container (shared chrome)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[900]
                        : Colors.white,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20)),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, -4))
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: widget.contentBuilder(context, scrollController),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
