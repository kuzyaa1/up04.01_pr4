import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Guards Navigator pops and GoRouter replacements, including Cancel.
class DirtyGuard extends StatefulWidget {
  final ValueGetter<bool> isDirty;
  final Widget child;
  final String fallbackLocation;
  final String message;
  const DirtyGuard({
    super.key,
    required this.isDirty,
    required this.child,
    required this.fallbackLocation,
    this.message =
        'Есть несохранённые изменения. Закрыть форму без сохранения?',
  });
  static _DirtyGuardState? _active;
  static Future<bool> mayLeave() async => await _active?.confirmLeave() ?? true;
  @override
  State<DirtyGuard> createState() => _DirtyGuardState();
}

class _DirtyGuardState extends State<DirtyGuard> {
  bool _approved = false;
  Future<bool>? _confirmation;
  @override
  void initState() {
    super.initState();
    DirtyGuard._active = this;
  }

  @override
  void dispose() {
    if (identical(DirtyGuard._active, this)) DirtyGuard._active = null;
    super.dispose();
  }

  Future<bool> confirmLeave() async {
    if (_approved || !widget.isDirty()) return true;
    if (_confirmation != null) return _confirmation!;
    _confirmation = _ask();
    try {
      return await _confirmation!;
    } finally {
      _confirmation = null;
    }
  }

  Future<bool> _ask() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Есть несохранённые изменения'),
        content: Text(widget.message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Остаться')),
          FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Выйти без сохранения')),
        ],
      ),
    );
    if (leave == true && mounted) setState(() => _approved = true);
    return leave == true;
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: _approved || !widget.isDirty(),
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || !await confirmLeave() || !context.mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(widget.fallbackLocation);
            }
          });
        },
        child: widget.child,
      );
}
