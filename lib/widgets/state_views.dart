import 'package:flutter/material.dart';

import '../state/list_notifier.dart';

/// Состояния экрана со списком в одном виджете.
///
/// У экрана, который ходит за данными, четыре состояния, а не одно:
/// грузим, готово, пусто, сломалось. Раньше в каждом экране лежало по
/// три строчки с `CircularProgressIndicator`, а обработки ошибок не
/// было вовсе. Теперь в экране остаётся одна строка:
///
/// ```dart
/// if (notifier.status != LoadStatus.success) {
///   return ListStateView(notifier: notifier);
/// }
/// ```
class ListStateView<T> extends StatelessWidget {
  const ListStateView({super.key, required this.notifier});

  final ListNotifier<T> notifier;

  @override
  Widget build(BuildContext context) {
    if (notifier.status == LoadStatus.error) {
      return ErrorView(
        message: notifier.error ?? 'Не удалось загрузить данные.',
        onRetry: notifier.load,
      );
    }
    return const LoadingView();
  }
}

/// Индикатор загрузки.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Ошибка сети с кнопкой повтора.
///
/// Ошибка без возможности повторить бесполезна: единственный выход для
/// пользователя — перезагрузить страницу, а он про это не догадается.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Данные не загрузились', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Пустой список — это не ошибка и не загрузка, это третье состояние.
///
/// Экран, который в этой ситуации показывает просто ничего, выглядит
/// сломанным.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.message, this.hint, this.action});

  final String message;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Недостаточно прав.
///
/// Отдельно от ошибки: человек ничего не сломал, просто у его роли нет
/// такого права.
class ForbiddenView extends StatelessWidget {
  const ForbiddenView({super.key, this.message, this.action});

  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('Недостаточно прав', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message ?? 'Это действие доступно другой роли.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}
