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
  final VoidCallback? onSoftDelete;

  /// Что делать при нажатии «Восстановить».
  final VoidCallback? onRestore;

  /// Что делать при нажатии «Стереть навсегда» (физическое удаление).
  final VoidCallback? onHardDelete;

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
    required Permissions permissions,
    required VoidCallback onEdit,
    VoidCallback? onSoftDelete,
    VoidCallback? onRestore,
    VoidCallback? onHardDelete,
    bool isDeleted = false,
  }) {
    return [
      if (permissions.canUpdate)
        IconButton(
          tooltip: 'Редактировать',
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
        ),
      if (isDeleted)
        if (permissions.canRestore)
          IconButton(
            tooltip: 'Восстановить',
            onPressed: onRestore,
            icon: const Icon(Icons.restore),
          )
        else if (permissions.canSoftDelete)
          IconButton(
            tooltip: 'Удалить',
            onPressed: onSoftDelete,
            icon: const Icon(Icons.delete_outline),
          ),
      if (permissions.canHardDelete)
        IconButton(
          tooltip: 'Стереть навсегда',
          onPressed: onHardDelete,
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
  final VoidCallback onPressed;

  const CreateButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<SessionStore>().permissions;
    if (!permissions.canCreate) return const SizedBox.shrink();
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}

/// Панель массовых операций с учётом прав.
class BulkActions extends StatelessWidget {
  final int count;
  final VoidCallback onDelete;
  final VoidCallback onErase;
  final VoidCallback onClearSelection;

  const BulkActions({
    super.key,
    required this.count,
    required this.onDelete,
    required this.onErase,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<SessionStore>().permissions;
    if (!permissions.canBulkDelete) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        Text('Выбрано: $count'),
        if (permissions.canSoftDelete)
          FilledButton(onPressed: onDelete, child: const Text('Удалить')),
        if (permissions.canHardDelete)
          OutlinedButton(
              onPressed: onErase, child: const Text('Стереть навсегда')),
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
            permissions.isAuthenticated
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
