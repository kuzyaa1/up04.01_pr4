import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Экран «нет доступа».
///
/// Показывается, когда пользователь без нужных прав открыл адрес формы
/// напрямую. Сама защита находится на сервере: даже если обойти эту
/// проверку, сервер вернёт 403.
class NoAccessScreen extends StatelessWidget {
  final String title;
  final String message;

  const NoAccessScreen({
    super.key,
    this.title = 'Недостаточно прав',
    this.message = 'Ваша роль не позволяет изменять данные студии.',
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 56, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Войти'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('На главную'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
