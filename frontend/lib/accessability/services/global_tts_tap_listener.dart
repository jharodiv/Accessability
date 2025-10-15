// global_tts_tap_listener.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'tts_service.dart';

/// Global listener that tries to speak the label of the tapped widget.
/// This variant safely handles nullable `verboseLogging` and avoids the
/// null-bool crash by normalizing the flag before use.
class GlobalTtsTapListener extends StatelessWidget {
  final Widget child;
  final bool? requireSemantics;
  final bool? verboseLogging;

  const GlobalTtsTapListener({
    Key? key,
    required this.child,
    this.requireSemantics = false,
    this.verboseLogging = true,
  }) : super(key: key);

  // Normalized local getter to avoid null-bool issues.
  bool get _vl => verboseLogging == true;
  bool get _requireSemantics => requireSemantics == true;

  void _onPointerUp(PointerUpEvent event) {
    final pos = event.position;
    if (_vl) debugPrint('[GlobalTts] pointerUp at $pos');
    _trySpeakAt(pos);
  }

  void _trySpeakAt(Offset globalPosition) {
    // 1) Try semantics tree
    final semanticsOwner = WidgetsBinding.instance.pipelineOwner.semanticsOwner;
    if (semanticsOwner != null) {
      final SemanticsNode? root = semanticsOwner.rootSemanticsNode;
      if (root != null) {
        if (_vl) debugPrint('[GlobalTts] semantics root exists');
        final SemanticsNode? node = _hitSemanticsNode(root, globalPosition);
        if (node != null) {
          final label = (node.label ?? '').trim();
          if (label.isNotEmpty) {
            if (_vl) debugPrint('[GlobalTts] semantics label found: "$label"');
            TtsService.instance.speak(label);
            return;
          } else {
            final data = node.getSemanticsData();
            if (data.hasAction(SemanticsAction.tap)) {
              if (_vl)
                debugPrint('[GlobalTts] actionable semantics node w/o label');
              if (!_requireSemantics) {
                // optional fallback phrase (uncomment if desired)
                // TtsService.instance.speak('Button');
                // return;
              }
            }
          }
        } else {
          if (_vl) debugPrint('[GlobalTts] no semantics node hit');
        }
      } else {
        if (_vl)
          debugPrint('[GlobalTts] semanticsOwner.rootSemanticsNode is null');
      }
    } else {
      if (_vl) debugPrint('[GlobalTts] pipelineOwner.semanticsOwner is null');
    }

    // 2) Fallback: RenderObject hit test + debugCreator -> Element -> Widget inspection
    try {
      if (_vl)
        debugPrint('[GlobalTts] attempting render-object hit test fallback');
      final HitTestResult result = HitTestResult();
      RendererBinding.instance.hitTest(result, globalPosition);

      // iterate entries from top-most to bottom-most by reversing a list copy
      final entries = result.path.toList().reversed;
      for (final entry in entries) {
        final target = entry.target;
        if (target is RenderObject) {
          final debugCreator = target.debugCreator;
          // debugCreator is only available in debug mode and is typically a DebugCreator.
          if (debugCreator is DebugCreator) {
            final Element element = debugCreator.element;
            if (element == null) continue;

            final Widget widget = element.widget;
            if (_vl)
              debugPrint(
                  '[GlobalTts] hit render object widget: ${widget.runtimeType}');

            // If widget is Text, speak its data
            if (widget is Text) {
              final text =
                  (widget.data ?? _textFromInlineSpan(widget.textSpan)).trim();
              if (text.isNotEmpty) {
                if (_vl) debugPrint('[GlobalTts] found Text widget: "$text"');
                TtsService.instance.speak(text);
                return;
              }
            }

            // Walk up ancestors (including the element) to find Semantics, Tooltip or Text
            bool spoken = false;
            element.visitAncestorElements((ancestor) {
              final w = ancestor.widget;

              if (w is Semantics) {
                // Semantics widget exposes its properties via `.properties`
                final String label =
                    (w.properties?.label ?? '').toString().trim();
                if (label.isNotEmpty) {
                  if (_vl)
                    debugPrint(
                        '[GlobalTts] found Semantics widget label: "$label"');
                  TtsService.instance.speak(label);
                  spoken = true;
                  return false; // stop visiting ancestors
                }
              }

              if (w is Tooltip) {
                final String message = (w.message ?? '').toString().trim();
                if (message.isNotEmpty) {
                  if (_vl)
                    debugPrint('[GlobalTts] found Tooltip message: "$message"');
                  TtsService.instance.speak(message);
                  spoken = true;
                  return false;
                }
              }

              if (w is Text) {
                final String text =
                    (w.data ?? _textFromInlineSpan(w.textSpan)).trim();
                if (text.isNotEmpty) {
                  if (_vl)
                    debugPrint(
                        '[GlobalTts] found ancestor Text widget: "$text"');
                  TtsService.instance.speak(text);
                  spoken = true;
                  return false;
                }
              }

              return true; // continue visiting ancestors
            });

            if (spoken) return;
          }
        }
      }

      if (_vl) debugPrint('[GlobalTts] fallback found nothing to speak');
    } catch (e, st) {
      debugPrint('[GlobalTts] render-object fallback error: $e\n$st');
    }
  }

  // Traverse semantics nodes to find deepest node containing the point.
  SemanticsNode? _hitSemanticsNode(SemanticsNode root, Offset globalPosition) {
    SemanticsNode? hitNode;
    void walk(SemanticsNode node) {
      try {
        if (node.rect.contains(globalPosition)) {
          final children = node
              .debugListChildrenInOrder(DebugSemanticsDumpOrder.inverseHitTest)
              .toList();
          for (final child in children.reversed) {
            walk(child);
            if (hitNode != null) return;
          }
          final label = (node.label ?? '').trim();
          final data = node.getSemanticsData();
          final bool isActionable = data.hasAction(SemanticsAction.tap);
          if (label.isNotEmpty || isActionable) {
            hitNode = node;
          }
        }
      } catch (_) {
        // ignore nodes with weird transforms, etc.
      }
    }

    try {
      walk(root);
    } catch (_) {}
    return hitNode;
  }

  // Walk InlineSpan (TextSpan/WidgetSpan) to extract text.
  String _textFromInlineSpan(InlineSpan? span) {
    if (span == null) return '';
    final buffer = StringBuffer();

    void collect(InlineSpan s) {
      if (s is TextSpan) {
        if (s.text != null) buffer.write(s.text);
        if (s.children != null) {
          for (final child in s.children!) {
            if (child is InlineSpan) collect(child);
          }
        }
      } else if (s is WidgetSpan) {
        // ignore widget spans (no readable text)
      }
    }

    collect(span);
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _onPointerUp,
      child: child,
    );
  }
}
