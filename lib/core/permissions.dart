/// Права ролей.
///
/// Правила здесь повторяют те, что проверяет сервер: клиент скрывает
/// недоступные действия, чтобы пользователь не нажимал на кнопку,
/// которая всё равно вернёт 403. Но проверка прав на клиенте — это
/// удобство интерфейса, а не защита: настоящая защита всегда на сервере.
library;

/// Уровни ролей. Чем выше, тем больше прав.
enum UserRole {
  /// Клиент: бронирует съёмки, видит только свои бронирования.
  client(1, 'Клиент'),

  /// Фотограф: работает с залами, к которым привязан.
  photographer(2, 'Фотограф'),

  /// Менеджер смены: ведёт каталог студии и бронирования.
  manager(3, 'Менеджер'),

  /// Администратор: администратор студии.
  admin(4, 'Администратор');

  const UserRole(this.level, this.title);

  /// Числовой уровень роли: чем выше, тем больше прав.
  final int level;

  /// Название роли для интерфейса.
  final String title;

  /// Разбирает название роли, пришедшее с сервера.
  ///
  /// Неизвестная роль трактуется как `client` — наименьшие права.
  static UserRole parse(String? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return UserRole.client;
  }

  /// Роль не ниже указанной.
  bool atLeast(UserRole min) => level >= min.level;

  /// Можно создавать, изменять и логически удалять записи.
  bool get canManage => atLeast(UserRole.manager);

  /// Можно удалять записи физически и восстанавливать их.
  bool get canAdminister => atLeast(UserRole.admin);

  /// Можно только читать.
  bool get isReadOnly => !canManage;
}

/// Набор прав конкретного пользователя.
///
/// Действия в интерфейсе проверяются через этот объект, а не через
/// сравнение строк с названием роли: правила собраны в одном месте.
class Permissions {
  const Permissions(this.role) : isGuest = false;

  /// Права гостя — вход не выполнен.
  const Permissions.guest()
      : role = UserRole.client,
        isGuest = true;

  final UserRole role;

  /// Выполнен ли вход.
  ///
  /// Отличать гостя от вошедшего клиента нужно: у клиента роль
  /// `client`, но он всё равно вошёл в систему и видит аватар.
  final bool isGuest;

  /// Вошёл ли пользователь в систему.
  bool get isAuthenticated => !isGuest;

  /// Можно читать каталог. Гость тоже может.
  bool get canRead => true;

  /// Можно создавать записи.
  bool get canCreate => role.canManage;

  /// Можно управлять записями — то же, что [canCreate].
  bool get canManage => canCreate;

  /// Можно только читать: изменение данных запрещено.
  bool get isReadOnly => !canManage;

  /// Можно изменять записи.
  bool get canUpdate => role.canManage;

  /// Можно помечать записи удалёнными.
  bool get canSoftDelete => role.canManage;

  /// Можно удалять записи физически.
  bool get canHardDelete => role.canAdminister;

  /// Можно восстанавливать удалённые записи.
  bool get canRestore => role.canAdminister;

  /// Можно удалять несколько записей за одну операцию.
  bool get canBulkDelete => role.canManage;

  /// Можно управлять пользователями.
  bool get canManageUsers => role.canAdminister;

  /// Человекочитаемое описание прав для главной страницы.
  List<String> get summary => [
        'Просмотр каталога студии',
        if (canCreate) 'Создание и изменение записей',
        if (canSoftDelete) 'Логическое удаление',
        if (canBulkDelete) 'Множественное удаление',
        if (canRestore) 'Восстановление удалённых записей',
        if (canHardDelete) 'Физическое удаление',
        if (!canManage)
          isAuthenticated
              ? 'Изменение данных запрещено ролью «${role.title}»'
              : 'Изменение данных доступно после входа',
      ];
}
