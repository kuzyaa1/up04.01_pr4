import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';

class SessionWatcher extends StatefulWidget {
  const SessionWatcher({super.key, required this.session, required this.child});
  final SessionStore session;
  final Widget child;
  @override
  State<SessionWatcher> createState() => _SessionWatcherState();
}

class _SessionWatcherState extends State<SessionWatcher> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_key);
    _timer = Timer.periodic(
        const Duration(seconds: 1), (_) => widget.session.checkLimits());
  }

  bool _key(KeyEvent event) {
    widget.session.recordActivity();
    return false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => widget.session.recordActivity(),
        onPointerMove: (_) => widget.session.recordActivity(),
        onPointerHover: (_) => widget.session.recordActivity(),
        onPointerSignal: (_) => widget.session.recordActivity(),
        child: widget.child,
      );
}

class SessionWarning extends StatelessWidget {
  const SessionWarning({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    return Column(children: [
      if (session.inactivityWarning && session.isAuthenticated)
        Material(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          'Выход из-за неактивности через ${session.secondsRemaining} с.')),
                  TextButton(
                      onPressed: session.recordActivity,
                      child: const Text('Продолжить работу')),
                ]))),
      Expanded(child: child),
    ]);
  }
}
