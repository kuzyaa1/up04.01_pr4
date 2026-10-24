import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/booking_query.dart';
import '../models/client_query.dart';
import '../models/equipment_query.dart';
import '../models/hall_query.dart';
import '../models/photographer_query.dart';
import '../screens/booking_form_screen.dart';
import '../screens/booking_list_screen.dart';
import '../screens/client_form_screen.dart';
import '../screens/client_list_screen.dart';
import '../screens/equipment_form_screen.dart';
import '../screens/equipment_list_screen.dart';
import '../screens/hall_form_screen.dart';
import '../screens/hall_list_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/no_access_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/photographer_form_screen.dart';
import '../screens/photographer_list_screen.dart';
import '../state/session.dart';

/// Адреса, куда пускают только тех, кто вошёл и имеет право.
///
/// Список короткий и заданный явно. Обратный подход — «закрыто всё,
/// кроме перечисленного» — надёжнее, но для приложения, которое почти
/// целиком доступно гостям, он выглядит вывернутым наизнанку.
bool _requiresSignIn(String location) {
  return location.endsWith('/new') || location.endsWith('/edit');
}

/// Страница формы, если у пользователя есть право на изменение данных.
///
/// Проверка выполняется здесь, а не внутри каждой формы: правило одно
/// на все пять сущностей. Настоящая защита — на сервере.
class _GuardedForm extends StatelessWidget {
  final Widget child;

  const _GuardedForm({required this.child});

  @override
  Widget build(BuildContext context) {
    final permissions = context.watch<SessionStore>().permissions;
    if (!permissions.canUpdate) {
      return const NoAccessScreen(
        message: 'Ваша роль не позволяет изменять данные студии. '
            'Войдите под учётной записью менеджера.',
      );
    }
    return child;
  }
}

/// Создаёт роутер приложения.
///
/// Роутеру нужна сессия: по её состоянию он решает, пускать ли гостя
/// на страницу формы и куда вернуть человека после входа.
GoRouter createRouter(SessionStore session) {
  return GoRouter(
    initialLocation: '/',

    // Пересчитать перенаправления, когда пользователь вошёл или вышел.
    // Без этого после входа человек так и останется на экране входа.
    refreshListenable: session,

    redirect: (context, state) {
      final location = state.matchedLocation;

      // Пока проверяется сохранённый токен, ничего не решаем: иначе при
      // каждой перезагрузке страницы будет мелькать экран входа.
      if (!session.isKnown) return null;

      if (!session.isAuthenticated && _requiresSignIn(location)) {
        // Запоминаем, куда человек шёл, чтобы вернуть его туда после входа.
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      if (session.isAuthenticated && location == '/login') return '/';

      return null;
    },

    routes: [
      // Экран входа живёт вне общего каркаса: меню разделов на нём не нужно.
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),

      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/halls',
          builder: (_, s) => HallListScreen(query: HallQuery.fromUri(s.uri))),
      GoRoute(
        path: '/halls/new',
        builder: (_, __) => const _GuardedForm(child: HallFormScreen()),
      ),
      GoRoute(
        path: '/halls/:id/edit',
        builder: (_, s) => _GuardedForm(
          child: HallFormScreen(id: int.tryParse(s.pathParameters['id'] ?? '')),
        ),
      ),
      GoRoute(
          path: '/photographers',
          builder: (_, s) =>
              PhotographerListScreen(query: PhotographerQuery.fromUri(s.uri))),
      GoRoute(
        path: '/photographers/new',
        builder: (_, __) => const _GuardedForm(child: PhotographerFormScreen()),
      ),
      GoRoute(
        path: '/photographers/:id/edit',
        builder: (_, s) => _GuardedForm(
          child: PhotographerFormScreen(
              id: int.tryParse(s.pathParameters['id'] ?? '')),
        ),
      ),
      GoRoute(
          path: '/bookings',
          builder: (_, s) =>
              BookingListScreen(query: BookingQuery.fromUri(s.uri))),
      GoRoute(
        path: '/bookings/new',
        builder: (_, __) => const _GuardedForm(child: BookingFormScreen()),
      ),
      GoRoute(
        path: '/bookings/:id/edit',
        builder: (_, s) => _GuardedForm(
          child:
              BookingFormScreen(id: int.tryParse(s.pathParameters['id'] ?? '')),
        ),
      ),
      GoRoute(
          path: '/clients',
          builder: (_, s) =>
              ClientListScreen(query: ClientQuery.fromUri(s.uri))),
      GoRoute(
        path: '/clients/new',
        builder: (_, __) => const _GuardedForm(child: ClientFormScreen()),
      ),
      GoRoute(
        path: '/clients/:id/edit',
        builder: (_, s) => _GuardedForm(
          child:
              ClientFormScreen(id: int.tryParse(s.pathParameters['id'] ?? '')),
        ),
      ),
      GoRoute(
          path: '/equipment',
          builder: (_, s) =>
              EquipmentListScreen(query: EquipmentQuery.fromUri(s.uri))),
      GoRoute(
        path: '/equipment/new',
        builder: (_, __) => const _GuardedForm(child: EquipmentFormScreen()),
      ),
      GoRoute(
        path: '/equipment/:id/edit',
        builder: (_, s) => _GuardedForm(
          child: EquipmentFormScreen(
              id: int.tryParse(s.pathParameters['id'] ?? '')),
        ),
      ),
    ],
    errorBuilder: (_, s) => NotFoundScreen(location: s.uri.toString()),
  );
}
