import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/permissions.dart';
import '../state/session.dart';
import '../widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final user = session.user;
    final entities = [
      (
        Icons.event_available,
        'Бронирования',
        '/bookings',
        'Центральная сущность: связь с залами, клиентами и фотографами'
      ),
      (Icons.meeting_room, 'Залы', '/halls', 'Один ко многим с бронированиями'),
      (
        Icons.camera_alt,
        'Фотографы',
        '/photographers',
        'Многие ко многим с залами и бронированиями'
      ),
      (Icons.people, 'Клиенты', '/clients', 'Один к одному с абонементом'),
      (
        Icons.lightbulb_outline,
        'Оборудование',
        '/equipment',
        'Многие к одному с залами'
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('FocusFrames — фотостудия'),
        actions: const [SessionAction()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Система бронирования фотостудии',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                  'Пять сущностей со всеми тремя типами связей: формы создания '
                  'и редактирования, поиск, фильтрация, сортировка, '
                  'постраничный вывод и логическое с физическое удаление.',
                ),
                const SizedBox(height: 16),
                _sessionCard(context, session, user),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final entity in entities)
                      SizedBox(
                        width: 250,
                        child: Card(
                          child: InkWell(
                            onTap: () => context.go(entity.$3),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(entity.$1, size: 28),
                                  const SizedBox(height: 8),
                                  Text(entity.$2,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 4),
                                  Text(entity.$4,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ),
                          ),
                        ),
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

  Widget _sessionCard(
      BuildContext context, SessionStore session, AppUser? user) {
    final permissions = session.permissions;
    if (user == null) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Вы не вошли в систему: каталог доступен для чтения, '
                    'но изменять записи нельзя — сервер вернёт 401 или 403.',
                  ),
                ),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Войти'),
                ),
              ]),
              const SizedBox(height: 12),
              _permissionsList(context, permissions),
            ],
          ),
        ),
      );
    }
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.account_circle_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Роль: ${permissions.role.title} · ${user.email}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (permissions.isReadOnly)
                const Chip(
                  avatar: Icon(Icons.lock_outline, size: 16),
                  label: Text('только чтение'),
                ),
            ]),
            const SizedBox(height: 12),
            _permissionsList(context, permissions),
          ],
        ),
      ),
    );
  }

  Widget _permissionsList(BuildContext context, Permissions permissions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Что вам доступно:',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        for (final rule in permissions.summary)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(children: [
              Icon(
                rule.startsWith('Изменение') ? Icons.block : Icons.check,
                size: 16,
                color: rule.startsWith('Изменение')
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(rule, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
      ],
    );
  }
}
