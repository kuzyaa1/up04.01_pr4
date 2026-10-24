import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/storage.dart';
import 'repositories/api_booking_repository.dart';
import 'repositories/api_client_repository.dart';
import 'repositories/api_equipment_repository.dart';
import 'repositories/api_hall_repository.dart';
import 'repositories/api_photographer_repository.dart';
import 'repositories/booking_repository.dart';
import 'repositories/client_repository.dart';
import 'repositories/equipment_repository.dart';
import 'repositories/hall_repository.dart';
import 'repositories/photographer_repository.dart';
import 'state/catalog_notifier.dart';
import 'state/catalog_notifiers.dart';
import 'state/list_notifiers.dart';
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final preferences = await SharedPreferences.getInstance();
  final migrationNotice = VersionedStore.takeNotice(preferences);

  final session = SessionStore();
  await session.restore(preferences);

  // Токен доступа берётся у сессии в момент запроса, поэтому вход
  // и выход работают без пересборки клиента.
  final dio = buildDio(tokenProvider: () => session.token);
  final auth = AuthRepository(dio);

  // Профиль пользователя восстанавливается по сохранённому токену.
  // Без этого после перезагрузки страницы роль была бы потеряна
  // и приложение работало бы как гость.
  await session.restoreUser(auth);

  runApp(MultiProvider(
    providers: [
      Provider<Dio>(create: (_) => dio),
      // SessionStore — ChangeNotifier: через него роутер узнаёт о входе
      // и выходе. Обычный Provider на Listenable жаловался бы в консоль.
      ChangeNotifierProvider<SessionStore>.value(value: session),
      Provider<AuthRepository>(create: (_) => auth),

      // Реализации репозиториев заменены на сетевые.
      // Интерфейсы остались прежними, поэтому экраны не изменились.
      Provider<HallRepository>(create: (_) => ApiHallRepository(dio)),
      Provider<PhotographerRepository>(
          create: (_) => ApiPhotographerRepository(dio)),
      Provider<BookingRepository>(create: (_) => ApiBookingRepository(dio)),
      Provider<ClientRepository>(create: (_) => ApiClientRepository(dio)),
      Provider<EquipmentRepository>(create: (_) => ApiEquipmentRepository(dio)),

      ChangeNotifierProvider(
          create: (c) => HallListNotifier(c.read<HallRepository>())),
      ChangeNotifierProvider(
          create: (c) =>
              PhotographerListNotifier(c.read<PhotographerRepository>())),
      ChangeNotifierProvider(
          create: (c) => BookingListNotifier(c.read<BookingRepository>())),
      ChangeNotifierProvider(
          create: (c) => ClientListNotifier(c.read<ClientRepository>())),
      ChangeNotifierProvider(
          create: (c) => EquipmentListNotifier(c.read<EquipmentRepository>())),
      ChangeNotifierProvider(
        create: (c) => CatalogNotifier(
          halls: c.read<HallRepository>(),
          photographers: c.read<PhotographerRepository>(),
          clients: c.read<ClientRepository>(),
          bookings: c.read<BookingRepository>(),
          equipment: c.read<EquipmentRepository>(),
        )..load(),
      ),
    ],
    child:
        PhotoStudioApp(notice: migrationNotice, router: createRouter(session)),
  ));
}

class PhotoStudioApp extends StatelessWidget {
  final String? notice;
  final GoRouter router;

  const PhotoStudioApp({super.key, this.notice, required this.router});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'FocusFrames',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        routerConfig: router,
        builder: (context, child) {
          if (notice == null) return child ?? const SizedBox.shrink();
          return MigrationNoticeHost(message: notice!, child: child!);
        },
      );
}

class MigrationNoticeHost extends StatefulWidget {
  final String message;
  final Widget child;
  const MigrationNoticeHost(
      {super.key, required this.message, required this.child});

  @override
  State<MigrationNoticeHost> createState() => _MigrationNoticeHostState();
}

class _MigrationNoticeHostState extends State<MigrationNoticeHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.storage, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.message)),
        ]),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
