import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DirtyGuard extends StatelessWidget {
  final bool dirty;
  final Widget child;
  final String message;
  const DirtyGuard({
    super.key,
    required this.dirty,
    required this.child,
    this.message =
        'Есть несохранённые изменения. Закрыть форму без сохранения?',
  });
  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          confirmLeave(context, message);
        },
        child: child,
      );
  static Future<void> confirmLeave(BuildContext context, String message) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Есть несохранённые изменения'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Остаться'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Выйти без сохранения'),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      context.pop();
    }
  }
}
