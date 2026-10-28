import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_studio_portal/models/booking.dart';
import 'package:photo_studio_portal/repositories/booking_repository.dart';
import 'package:photo_studio_portal/repositories/persistent_booking_repository.dart';
import 'package:photo_studio_portal/repositories/photo_studio_repositories.dart';
import 'package:photo_studio_portal/screens/booking_form_screen.dart';
import 'package:photo_studio_portal/state/catalog_notifier.dart';
import 'package:photo_studio_portal/state/session.dart';
import 'package:photo_studio_portal/widgets/entity_form.dart';

class CapturingBookings extends PersistentBookingRepository {
  CapturingBookings(super.prefs);
  Booking? submitted;
  @override
  Future<Booking> save(Booking booking) async {
    submitted = booking;
    return booking;
  }
}

void main() {
  testWidgets('клиент бронирует зал без выбора чужого клиента и ввода кода',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final local = PhotoStudioRepositories(prefs);
    final bookings = CapturingBookings(prefs);
    final session = SessionStore()
      ..setUser(const AppUser(
          id: 4,
          clientId: 1,
          username: 'client',
          fullName: 'Мой профиль',
          email: 'own@example.com',
          role: 'client'));
    final catalog = CatalogNotifier(
        halls: local.halls,
        photographers: local.photographers,
        clients: local.clients,
        bookings: local.bookings,
        equipment: local.equipment,
        includeClients: false);
    await catalog.load();
    final router = GoRouter(initialLocation: '/new', routes: [
      GoRoute(
          path: '/new',
          builder: (_, __) =>
              const BookingFormScreen(selfService: true, initialHallId: 1)),
      GoRoute(
          path: '/my-bookings',
          builder: (_, __) =>
              const Scaffold(body: Text('Мои бронирования после сохранения'))),
    ]);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<SessionStore>.value(value: session),
      ChangeNotifierProvider<CatalogNotifier>.value(value: catalog),
      Provider<BookingRepository>.value(value: bookings),
    ], child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    final form = tester.state<EntityFormState>(find.byType(EntityForm));
    final specs = tester.widget<EntityForm>(find.byType(EntityForm)).fields;
    expect(specs.any((f) => f.name == 'clientId'), isFalse);
    expect(specs.any((f) => f.name == 'accessCode'), isFalse);
    expect(form.number('hallId'), 1);
    expect(form.string('email'), 'own@example.com');
    form.setValue('photographerIds', <int>[1]);
    form.setValue('date', '2099-01-15');
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'Создать бронирование');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(bookings.submitted, isNotNull);
    expect(bookings.submitted!.clientId, 1);
    expect(bookings.submitted!.clientName, 'Мой профиль');
    expect(bookings.submitted!.hallId, 1);
    expect(bookings.submitted!.accessCode, isEmpty);
    expect(router.routeInformationProvider.value.uri.path, '/my-bookings');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    session.dispose();
    catalog.dispose();
  });
}
