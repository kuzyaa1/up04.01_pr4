import 'dart:async';
import 'common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../state/session.dart';

/// Кнопки действий над записью с учётом прав текущего пользователя.
///
/// Правила проверки прав собраны здесь, а не размазаны по экранам.
/// Недоступное действие просто не показывается: нажать на кнопку,
/// которая всё равно вернёт 403, бессмысленно.
///
/// Важно: скрытие кнопки — это удобство интерфейса, а не защита.
/// Настоящая проверка выполняется на сервере, и клиент не может её обойти.
class RecordActions extends StatelessWidget {
  /// Что делать при нажатии «Редактировать».
  final VoidCallback onEdit;

  /// Что делать при нажатии «Удалить» (логическое удаление).
  final FutureOr<void> Function()? onSoftDelete;

  /// Что делать при нажатии «Восстановить».
  final FutureOr<void> Function()? onRestore;

  /// Что делать при нажатии «Стереть навсегда» (физическое удаление).
  final FutureOr<void> Function()? onHardDelete;

  /// Запись удалена: показывать «Восстановить» вместо «Удалить».
  final bool isDeleted;

  const RecordActions({
    super.key,
    required this.onEdit,
    this.onSoftDelete,
    this.onRestore,
    this.onHardDelete,
    this.isDeleted = false,
  });

  /// Кнопки действий в виде списка.
  ///
  /// Список, а не готовый виджет: ячейка таблицы и карточка кладут
  /// кнопки в свои контейнеры (строку таблицы или `Wrap`).
  static List<Widget> buttons({
    String collection = 'bookings',
    VoidCallback? onBook,
    VoidCallback? onView,
    required BuildContext context,
    required Permissions permissions,
    required VoidCallback onEdit,
    FutureOr<void> Function()? onSoftDelete,
    FutureOr<void> Function()? onRestore,
    FutureOr<void> Function()? onHardDelete,
    bool isDeleted = false,
  }) {
    return [
      if (onBook != null)
        IconButton(
            tooltip: 'Забронировать зал',
            onPressed: onBook,
            icon: const Icon(Icons.event_available)),
      if (onView != null)
        IconButton(
            tooltip: 'Просмотреть',
            onPressed: onView,
            icon: const Icon(Icons.visibility_outlined)),
      if (permissions.canManageEntity(collection))
        IconButton(
          tooltip: 'Редактировать',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
      if (isDeleted && permissions.canRestore)
        IconButton(
          tooltip: 'Восстановить',
          onPressed: onRestore == null ? null : () => _run(context, onRestore),
          icon: const Icon(Icons.restore),
        ),
      if (!isDeleted && permissions.canManageEntity(collection))
        IconButton(
          tooltip: 'Удалить',
          onPressed:
              onSoftDelete == null ? null : () => _run(context, onSoftDelete),
          icon: const Icon(Icons.delete_outline),
        ),
      if (permissions.canHardDelete)
        IconButton(
          tooltip: 'Стереть навсегда',
          onPressed:
              onHardDelete == null ? null : () => _run(context, onHardDelete),
          icon: const Icon(Icons.delete_forever),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<SessionStore>().permissions;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: buttons(
        context: context,
        permissions: permissions,
        onEdit: onEdit,
        onSoftDelete: onSoftDelete,
        onRestore: onRestore,
        onHardDelete: onHardDelete,
        isDeleted: isDeleted,
      ),
    );
  }
}

/// Кнопка «Создать» с учётом прав.
class CreateButton extends StatelessWidget {
  final String label;
  final String collection;
  final VoidCallback onPressed;

  const CreateButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.collection = 'bookings'});

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<SessionStore>().permissions;
    if (!permissions.canCreateEntity(collection)) {
      return const SizedBox.shrink();
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}

/// Панель массовых операций с учётом прав.
class BulkActions extends StatelessWidget {
  final String collection;
  final int count;
  final FutureOr<void> Function() onDelete;
  final FutureOr<void> Function() onErase;
  final VoidCallback onClearSelection;

  const BulkActions({
    super.key,
    required this.count,
    this.collection = 'bookings',
    required this.onDelete,
    required this.onErase,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<SessionStore>().permissions;
    if (!permissions.canManageEntity(collection)) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      children: [
        Text('Выбрано: $count'),
        if (permissions.canSoftDelete)
          FilledButton(
              onPressed: () => _run(context, onDelete),
              child: const Text('Удалить')),
        if (permissions.canHardDelete)
          OutlinedButton(
              onPressed: () => _run(context, onErase),
              child: const Text('Стереть навсегда')),
        TextButton(
            onPressed: onClearSelection, child: const Text('Снять выделение')),
      ],
    );
  }
}

/// Плашка, объясняющая, почему недоступны действия над записями.
///
/// Показывается гостю и клиенту, чтобы ограничение не выглядело
/// поломкой интерфейса.
class ReadOnlyNotice extends StatelessWidget {
  const ReadOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<SessionStore>().permissions;
    if (permissions.canManage) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        Icon(Icons.lock_outline, size: 18, color: Theme.of(context).hintColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            permissions.canBookOwn
                ? 'Вы можете бронировать залы для себя и продлевать свои записи. Справочники доступны для просмотра.'
                : permissions.isAuthenticated
                    ? 'Роль «${permissions.role.title}»: только просмотр. '
                        'Изменение данных доступно менеджеру студии.'
                    : 'Вы не вошли в систему: доступен только просмотр. '
                        'Войдите под учётной записью менеджера, чтобы изменять данные.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ]),
    );
  }
}

Future<void> _run(
    BuildContext context, FutureOr<void> Function() action) async {
  try {
    await action();
  } on Object catch (error) {
    if (context.mounted) await showOperationError(context, error);
  }
}
