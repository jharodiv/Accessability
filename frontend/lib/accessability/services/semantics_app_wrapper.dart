import 'package:flutter/material.dart';
import 'package:accessability/accessability/services/tts_service.dart';

/// Global wrapper that automatically detects AppBar back buttons
/// (even if wrapped in PreferredSize / Container) and adds semantics + TTS.
class SemanticsAppWrapper extends StatelessWidget {
  final Widget child;

  const SemanticsAppWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: _AppBarBackButtonInterceptor(child: child),
    );
  }
}

class _AppBarBackButtonInterceptor extends StatefulWidget {
  final Widget child;
  const _AppBarBackButtonInterceptor({required this.child});

  @override
  State<_AppBarBackButtonInterceptor> createState() =>
      _AppBarBackButtonInterceptorState();
}

class _AppBarBackButtonInterceptorState
    extends State<_AppBarBackButtonInterceptor> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<LayoutChangedNotification>(
      onNotification: (_) {
        // Could add dynamic refresh later if UI rebuilds
        return false;
      },
      child: _wrapBackButtons(context, widget.child),
    );
  }

  Widget _wrapBackButtons(BuildContext context, Widget widget) {
    // Recursively visit widgets
    if (widget is Scaffold && widget.appBar != null) {
      return _wrapScaffold(context, widget);
    }

    if (widget is PreferredSize &&
        widget.child is Container &&
        (widget.child as Container).child is AppBar) {
      // Directly wrap AppBar nested inside PreferredSize/Container
      final AppBar innerAppBar = (widget.child as Container).child as AppBar;
      return PreferredSize(
        preferredSize: widget.preferredSize,
        child: Container(
          decoration: (widget.child as Container).decoration,
          child: _wrapAppBar(context, innerAppBar),
        ),
      );
    }

    if (widget is MultiChildRenderObjectWidget) {
      final children = widget.children;
      return widget;
    }

    return widget;
  }

  Scaffold _wrapScaffold(BuildContext context, Scaffold scaffold) {
    final appBar = scaffold.appBar;
    if (appBar is PreferredSize &&
        appBar.child is Container &&
        (appBar.child as Container).child is AppBar) {
      final AppBar innerAppBar = (appBar.child as Container).child as AppBar;
      final newAppBar = PreferredSize(
        preferredSize: appBar.preferredSize,
        child: Container(
          decoration: (appBar.child as Container).decoration,
          child: _wrapAppBar(context, innerAppBar),
        ),
      );
      return scaffold.copyWith(appBar: newAppBar);
    }

    return scaffold;
  }

  AppBar _wrapAppBar(BuildContext context, AppBar appBar) {
    final leading = appBar.leading;
    if (leading is IconButton &&
        leading.icon is Icon &&
        (leading.icon as Icon).icon == Icons.arrow_back) {
      final IconButton original = leading as IconButton;

      final wrappedLeading = Semantics(
        label: 'Back',
        button: true,
        onTapHint: 'Go back',
        child: IconButton(
          // reuse same icon widget
          icon: original.icon,
          // preserve original onPressed if provided, otherwise just pop
          onPressed: () {
            if (original.onPressed != null) {
              original.onPressed!();
            } else {
              Navigator.maybePop(context);
            }
          },
          tooltip: original.tooltip ?? 'Back',
          // keep same visual splash/constraints by copying common properties
          iconSize: original.iconSize,
          padding: original.padding,
          alignment: original.alignment,
        ),
      );

      return AppBar(
        leading: wrappedLeading,
        title: appBar.title,
        centerTitle: appBar.centerTitle,
        elevation: appBar.elevation,
        backgroundColor: appBar.backgroundColor,
        foregroundColor: appBar.foregroundColor,
        actions: appBar.actions,
      );
    }

    return appBar;
  }
}

extension on Scaffold {
  Scaffold copyWith({PreferredSizeWidget? appBar}) {
    return Scaffold(
      appBar: appBar ?? this.appBar,
      body: body,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      endDrawer: endDrawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}
