import 'dart:async';
import 'package:flutter/widgets.dart';

/// Marks whether the subtree it wraps is the *currently visible* tab in
/// [AppShell]'s `IndexedStack`. All tabs stay mounted (so their state and
/// scroll position survive switching), but only one is on screen at a time —
/// screens use this to avoid polling the backend while they're hidden.
class TabVisibility extends InheritedWidget {
  final bool isActive;

  const TabVisibility({
    super.key,
    required this.isActive,
    required super.child,
  });

  /// Returns whether the calling screen is the visible tab. Defaults to
  /// `true` when there is no [TabVisibility] ancestor, so a screen used
  /// outside [AppShell] just behaves as "always visible".
  static bool of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<TabVisibility>();
    return widget?.isActive ?? true;
  }

  @override
  bool updateShouldNotify(TabVisibility oldWidget) =>
      oldWidget.isActive != isActive;
}

/// Drop-in polling behaviour for a screen that periodically refreshes data
/// from the backend. It:
///
///  * defers the first data load until the screen actually becomes visible
///    (so logging in doesn't fire every tab's initial requests at once),
///  * stops the refresh timer whenever the screen is scrolled off-screen, and
///  * runs one immediate refresh each time you switch back to the screen.
///
/// Implement [pollInterval] (return `Duration.zero` for load-once, no polling),
/// [onInitialLoad] and [onPoll]. Keep any listener wiring in your own
/// `initState`; if you override `dispose`, call `super.dispose()`.
mixin PollingScreenMixin<T extends StatefulWidget> on State<T> {
  Timer? _pollTimer;
  bool _didInitialLoad = false;
  bool _wasActive = false;

  /// How often to silently refresh while this screen is the visible tab.
  /// Return `Duration.zero` to load once (on first show + on each return)
  /// without a repeating timer.
  Duration get pollInterval;

  /// One-time full load. Runs the first time the screen becomes visible.
  void onInitialLoad();

  /// Silent refresh. Runs every [pollInterval] while the screen is visible,
  /// and once immediately each time the screen is re-shown.
  void onPoll();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TabVisibility.of(context);
    if (active == _wasActive) return; // only react to real visibility changes
    _wasActive = active;

    if (active) {
      if (!_didInitialLoad) {
        _didInitialLoad = true;
        onInitialLoad();
      } else {
        onPoll(); // returned to this tab — refresh right away
      }
      if (pollInterval > Duration.zero) {
        _pollTimer ??= Timer.periodic(pollInterval, (_) {
          if (mounted) onPoll();
        });
      }
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }
}
