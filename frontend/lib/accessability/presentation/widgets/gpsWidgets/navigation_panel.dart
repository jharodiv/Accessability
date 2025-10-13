// lib/presentation/screens/gpsscreen/widgets/navigation_info_panel.dart
import 'dart:async';
import 'package:flutter/material.dart';

/// NavigationInfoPanel
///
/// - Uses cached Futures (created once) instead of calling the async getters
///   directly in build(). This preserves the "Calculating..." state reliably
///   (like FutureBuilder did before) while avoiding re-creating futures on
///   every rebuild (which caused lag).
/// - Refreshes cached futures when the getter function identity changes,
///   when `refresh()` is called, or optionally on a periodic timer.
/// - Tuned for both light & dark mode visuals.
class NavigationInfoPanel extends StatefulWidget {
  final double bottomOffset;
  final bool isWheelchair;
  final Future<String> Function() getDestinationName;
  final Future<double> Function() getRemainingKm;
  final void Function(double delta) onDragUpdate;
  final VoidCallback onDragReset;

  /// Optional: if provided and > 0, the panel will auto-refresh cached futures
  /// every `autoRefreshSeconds` seconds.
  final int? autoRefreshSeconds;

  const NavigationInfoPanel({
    Key? key,
    required this.bottomOffset,
    required this.isWheelchair,
    required this.getDestinationName,
    required this.getRemainingKm,
    required this.onDragUpdate,
    required this.onDragReset,
    this.autoRefreshSeconds,
  }) : super(key: key);

  @override
  _NavigationInfoPanelState createState() => _NavigationInfoPanelState();
}

class _NavigationInfoPanelState extends State<NavigationInfoPanel> {
  Future<String>? _destinationFuture;
  Future<double>? _remainingFuture;

  // Keep last function identity so we only recreate futures when they change.
  late Future<String> Function() _cachedGetDestinationFn;
  late Future<double> Function() _cachedGetRemainingFn;

  Timer? _autoRefreshTimer;

  static const Color _brandPurple = Color(0xFF6750A4);
  static const Color _brandPurpleLight = Color(0xFFB388EB);

  @override
  void initState() {
    super.initState();
    _cachedGetDestinationFn = widget.getDestinationName;
    _cachedGetRemainingFn = widget.getRemainingKm;
    _createFutures();

    if (widget.autoRefreshSeconds != null && widget.autoRefreshSeconds! > 0) {
      _autoRefreshTimer =
          Timer.periodic(Duration(seconds: widget.autoRefreshSeconds!), (_) {
        _createFutures(refresh: true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant NavigationInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the parent changed the async getter functions (different function objects),
    // refresh cached futures so FutureBuilder shows waiting state again.
    if (!identical(widget.getDestinationName, _cachedGetDestinationFn) ||
        !identical(widget.getRemainingKm, _cachedGetRemainingFn)) {
      _cachedGetDestinationFn = widget.getDestinationName;
      _cachedGetRemainingFn = widget.getRemainingKm;
      _createFutures(refresh: true);
    }

    // If auto-refresh interval changed, restart timer
    if (widget.autoRefreshSeconds != oldWidget.autoRefreshSeconds) {
      _autoRefreshTimer?.cancel();
      if (widget.autoRefreshSeconds != null && widget.autoRefreshSeconds! > 0) {
        _autoRefreshTimer =
            Timer.periodic(Duration(seconds: widget.autoRefreshSeconds!), (_) {
          _createFutures(refresh: true);
        });
      }
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  /// (Re)create the cached Futures. If [refresh] is false and futures already
  /// exist, this does nothing (prevents unnecessary refreshes).
  void _createFutures({bool refresh = false}) {
    if (_destinationFuture == null || refresh) {
      try {
        _destinationFuture = _cachedGetDestinationFn();
      } catch (e) {
        // If the getter throws synchronously, wrap with a future error to keep behavior consistent.
        _destinationFuture = Future<String>.error(e);
      }
    }
    if (_remainingFuture == null || refresh) {
      try {
        _remainingFuture = _cachedGetRemainingFn();
      } catch (e) {
        _remainingFuture = Future<double>.error(e);
      }
    }
    if (refresh) {
      // cause rebuild so FutureBuilders pick up new futures and show waiting states
      if (mounted) setState(() {});
    }
  }

  /// Public: parent may call this (via a GlobalKey) to force refresh the values.
  void refresh() => _createFutures(refresh: true);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // Colors tuned for readability in both modes
    final Color panelSurface =
        isDark ? Colors.grey[850]! : Colors.white.withOpacity(0.95);
    final Color borderColor = isDark ? Colors.white12 : Colors.black12;
    final Color handleColor = isDark ? Colors.white24 : Colors.grey[400]!;
    final Color primaryText = isDark ? Colors.white : Colors.black87;
    final Color secondaryText = isDark ? Colors.white70 : Colors.black54;
    final Color iconPurple = isDark ? _brandPurpleLight : _brandPurple;
    final Color wheelGreen =
        isDark ? Colors.greenAccent.shade200 : Colors.green;

    return GestureDetector(
      onVerticalDragUpdate: (details) => widget.onDragUpdate(details.delta.dy),
      onVerticalDragEnd: (_) => widget.onDragReset(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panelSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (!isDark)
              const BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // small drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Route type row
            Row(
              children: [
                Icon(
                  widget.isWheelchair ? Icons.accessible : Icons.directions_car,
                  color: widget.isWheelchair ? wheelGreen : iconPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isWheelchair
                        ? 'Wheelchair-friendly route'
                        : 'Standard route',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: widget.isWheelchair ? wheelGreen : iconPurple,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Destination name (cached future -> reliable "Calculating..." state)
            FutureBuilder<String>(
              future: _destinationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // waiting -> show spinner + text
                  return Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconPurple),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Calculating...',
                          style: TextStyle(fontSize: 14, color: secondaryText)),
                    ],
                  );
                } else if (snapshot.hasError) {
                  // on error, show placeholder but keep color/readability
                  return Text('Destination',
                      style: TextStyle(fontSize: 14, color: secondaryText));
                } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Text(snapshot.data!,
                      style: TextStyle(fontSize: 14, color: primaryText));
                } else {
                  return Text('Destination',
                      style: TextStyle(fontSize: 14, color: secondaryText));
                }
              },
            ),

            const SizedBox(height: 8),

            // Remaining distance (cached future)
            FutureBuilder<double>(
              future: _remainingFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(iconPurple),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Calculating...',
                          style: TextStyle(fontSize: 14, color: secondaryText)),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Text('Distance remaining: —',
                      style: TextStyle(fontSize: 14, color: secondaryText));
                } else if (snapshot.hasData) {
                  return Text(
                    'Distance remaining: ${snapshot.data!.toStringAsFixed(1)} km',
                    style: TextStyle(fontSize: 14, color: primaryText),
                  );
                } else {
                  return Text('Distance remaining: —',
                      style: TextStyle(fontSize: 14, color: secondaryText));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
