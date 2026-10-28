import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_studio_portal/core/api_client.dart';
import 'package:photo_studio_portal/core/api_exceptions.dart';
import 'package:photo_studio_portal/models/hall_query.dart';
import 'package:photo_studio_portal/repositories/api_hall_repository.dart';
import 'package:photo_studio_portal/repositories/photo_studio_repositories.dart';
import 'package:photo_studio_portal/screens/hall_list_screen.dart';
import 'package:photo_studio_portal/state/catalog_notifier.dart';
import 'package:photo_studio_portal/state/list_notifier.dart';
import 'package:photo_studio_portal/state/list_notifiers.dart';
import 'package:photo_studio_portal/state/session.dart';

const reason = 'Удаление невозможно: связанных бронирований — 2';

class ConflictAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final reading = options.method == 'GET';
    return ResponseBody.fromString(
      jsonEncode(reading
          ? {
              'items': [
                {
                  'id': 1,
                  'name': 'Связанный зал',
                  'code': 'A-01',
                  'style': 'Лофт',
                  'capacity': 8,
                  'hourlyRate': 2000,
                  'bookingIds': [1, 2],
                }
              ],
              'page': 1,
              'size': 10,
              'total': 1,
            }
          : {'message': reason}),
      reading ? 200 : 409,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final bulk in [false, true]) {
    for (final hard in [false, true]) {
      testWidgets('409: bulk=$bulk hard=$hard сохраняет список и выделение',
          (tester) async {
        SharedPreferences.setMockInitialValues({});
        final local =
            PhotoStudioRepositories(await SharedPreferences.getInstance());
        final adapter = ConflictAdapter();
        final dio = buildDio()..httpClientAdapter = adapter;
        final notifier = HallListNotifier(ApiHallRepository(dio));
        final catalog = CatalogNotifier(
          halls: local.halls,
          photographers: local.photographers,
          clients: local.clients,
          bookings: local.bookings,
          equipment: local.equipment,
        );
        await catalog.load();
        final session = SessionStore()
          ..setUser(const AppUser(
              id: 1,
              username: 'admin',
              fullName: 'Админ',
              email: '',
              role: 'admin'));
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionStore>.value(value: session),
            ChangeNotifierProvider<CatalogNotifier>.value(value: catalog),
            ChangeNotifierProvider<HallListNotifier>.value(value: notifier),
          ],
          child: const MaterialApp(home: HallListScreen(query: HallQuery())),
        ));
        await tester.pumpAndSettle();
        expect(find.text('Связанный зал'), findsOneWidget);

        if (bulk) {
          notifier.toggle(1);
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(
              hard ? OutlinedButton : FilledButton,
              hard ? 'Стереть навсегда' : 'Удалить'));
        } else {
          await tester
              .tap(find.byTooltip(hard ? 'Стереть навсегда' : 'Удалить'));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(hard ? 'Стереть' : 'Удалить')));
        await tester.pumpAndSettle();

        expect(find.text('Операция не выполнена'), findsOneWidget);
        expect(find.textContaining(reason), findsOneWidget);
        expect(tester.takeException(), isNull);
        final mutations = adapter.requests.where((r) => r.method != 'GET');
        expect(mutations, hasLength(1));
        expect(mutations.single.method, bulk ? 'POST' : 'DELETE');
        expect(mutations.single.queryParameters['hard'],
            hard ? (bulk ? true : 'true') : null);
        expect(notifier.status, LoadStatus.success);
        expect(notifier.result.items.single.name, 'Связанный зал');
        if (bulk) expect(notifier.selected, contains(1));

        await tester.tap(find.text('Понятно'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Связанный зал'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        notifier.dispose();
        catalog.dispose();
        session.dispose();
        dio.close();
      });
    }
  }

  test('HTTP 409 сохраняет сообщение сервера в исключении', () async {
    final dio = buildDio()..httpClientAdapter = ConflictAdapter();
    await expectLater(
        ApiHallRepository(dio).softDelete(1),
        throwsA(isA<ConflictException>()
            .having((e) => e.message, 'message', reason)));
    dio.close();
  });
}
