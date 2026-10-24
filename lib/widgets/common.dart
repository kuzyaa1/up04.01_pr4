import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../state/session.dart';

const compactWidth = 900.0;

class AppScaffold extends StatelessWidget {
  final String title;
  final int index;
  final Widget child;
  final List<Widget> actions;

  /// Что делает кнопка «Обновить» в шапке.
  ///
  /// Нужна именно на вебе: страницу держат открытой часами, а данные за
  /// это время меняются. Тянуть за список сверху, как на телефоне, в
  /// браузере никто не станет.
  final VoidCallback? onRefresh;

  const AppScaffold(
      {super.key,
      required this.title,
      required this.index,
      required this.child,
      this.actions = const [],
      this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final destinations = [
      (Icons.event_available, 'Бронирования', '/bookings'),
      (Icons.meeting_room, 'Залы', '/halls'),
      (Icons.camera_alt, 'Фотографы', '/photographers'),
      (Icons.people, 'Клиенты', '/clients'),
      (Icons.lightbulb_outline, 'Оборудование', '/equipment'),
    ];
    final compact = MediaQuery.sizeOf(context).width < compactWidth;
    final app = AppBar(
      title: Text(title),
      actions: [
        ...actions,
        if (onRefresh != null)
          IconButton(
            tooltip: 'Обновить данные',
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        const SessionAction(),
      ],
    );
    if (compact) {
      return Scaffold(
          appBar: app,
          body: child,
          bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(destinations[i].$3),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.$1), label: d.$2)
              ]));
    }
    return Scaffold(
        appBar: app,
        body: Row(children: [
          NavigationRail(
              selectedIndex: index,
              extended: MediaQuery.sizeOf(context).width >= 1200,
              onDestinationSelected: (i) => context.go(destinations[i].$3),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: Icon(d.$1), label: Text(d.$2))
              ]),
          const VerticalDivider(width: 1),
          Expanded(child: child)
        ]));
  }
}

/// Кнопка текущего пользователя и выход из системы.
///
/// Показывает, под кем выполнен вход, и позволяет завершить сессию.
class SessionAction extends StatelessWidget {
  const SessionAction({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionStore>();
    final user = session.user;
    if (user == null) {
      return IconButton(
        tooltip: 'Войти',
        onPressed: () => context.go('/login'),
        icon: const Icon(Icons.login),
      );
    }
    return PopupMenuButton<String>(
      tooltip: user.fullName,
      icon: CircleAvatar(
        radius: 14,
        child: Text(
          user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
          style: const TextStyle(fontSize: 13),
        ),
      ),
      onSelected: (value) async {
        if (value != 'logout') return;
        // Всё, что нужно от контекста, берём до первого `await`:
        // после ожидания контекст мог быть размонтирован.
        final auth = context.read<AuthRepository>();
        final navigator = GoRouter.of(context);
        final prefs = await SharedPreferences.getInstance();
        // Сессия закрывается на сервере, затем удаляется из
        // локального хранилища.
        try {
          await auth.logout(session.refreshToken);
        } catch (_) {
          // Сервер может быть недоступен: локальную сессию
          // завершаем в любом случае.
        }
        await session.logout();
        await prefs.remove('focus_frame_api_token');
        await prefs.remove('focus_frame_api_refresh');
        navigator.go('/login');
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(user.role, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Выйти'),
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class Pager extends StatelessWidget {
  final int page, totalPages, total, size;
  final ValueChanged<int> onPage, onSize;
  const Pager(
      {super.key,
      required this.page,
      required this.totalPages,
      required this.total,
      required this.size,
      required this.onPage,
      required this.onSize});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Всего: $total'),
            DropdownButton<int>(
                value: size,
                items: [10, 25, 50]
                    .map((x) => DropdownMenuItem(value: x, child: Text('$x')))
                    .toList(),
                onChanged: (x) {
                  if (x != null) onSize(x);
                }),
            IconButton(
                onPressed: page > 1 ? () => onPage(1) : null,
                icon: const Icon(Icons.first_page)),
            IconButton(
                onPressed: page > 1 ? () => onPage(page - 1) : null,
                icon: const Icon(Icons.chevron_left)),
            Text('$page / $totalPages'),
            IconButton(
                onPressed: page < totalPages ? () => onPage(page + 1) : null,
                icon: const Icon(Icons.chevron_right)),
            IconButton(
                onPressed: page < totalPages ? () => onPage(totalPages) : null,
                icon: const Icon(Icons.last_page))
          ]));
}

Future<bool> confirm(BuildContext context, String text,
        {bool hard = false, String? title}) async =>
    (await showDialog<bool>(
        context: context,
        builder: (x) => AlertDialog(
                title: Text(title ??
                    (hard ? 'Физическое удаление' : 'Логическое удаление')),
                content: Text(text),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(x, false),
                      child: const Text('Отмена')),
                  FilledButton(
                      onPressed: () => Navigator.pop(x, true),
                      child: Text(hard ? 'Стереть' : 'Удалить'))
                ]))) ??
    false;
void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
}
