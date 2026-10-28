import 'package:flutter_test/flutter_test.dart';
import 'package:photo_studio_portal/core/permissions.dart';
import 'package:photo_studio_portal/state/session.dart';

/// Проверки разграничения прав.
///
/// Правила клиента повторяют правила сервера. Если они разойдутся,
/// пользователь либо увидит недоступную кнопку, либо не заметит
/// доступного действия.
void main() {
  group('разбор роли', () {
    test('известная роль разбирается', () {
      expect(UserRole.parse('client'), UserRole.client);
      expect(UserRole.parse('photographer'), UserRole.photographer);
      expect(UserRole.parse('manager'), UserRole.manager);
      expect(UserRole.parse('admin'), UserRole.admin);
    });

    test('неизвестная роль трактуется как клиент', () {
      expect(UserRole.parse('root'), UserRole.client);
      expect(UserRole.parse(null), UserRole.client);
      expect(UserRole.parse(''), UserRole.client);
    });
  });

  group('права клиента', () {
    const permissions = Permissions(UserRole.client);

    test('может читать каталог', () {
      expect(permissions.canRead, isTrue);
    });

    test('не может изменять данные', () {
      expect(permissions.canCreate, isFalse);
      expect(permissions.canUpdate, isFalse);
      expect(permissions.canSoftDelete, isFalse);
      expect(permissions.canBulkDelete, isFalse);
      expect(permissions.isReadOnly, isTrue);
    });

    test('не может физически удалять и восстанавливать', () {
      expect(permissions.canHardDelete, isFalse);
      expect(permissions.canRestore, isFalse);
    });
  });

  group('права менеджера', () {
    const permissions = Permissions(UserRole.manager);

    test('может создавать, изменять и удалять', () {
      expect(permissions.canCreate, isTrue);
      expect(permissions.canUpdate, isTrue);
      expect(permissions.canSoftDelete, isTrue);
      expect(permissions.canBulkDelete, isTrue);
      expect(permissions.isReadOnly, isFalse);
    });

    test('не может физически удалять и восстанавливать', () {
      // Физическое удаление и восстановление доступны только администратору.
      expect(permissions.canHardDelete, isFalse);
      expect(permissions.canRestore, isFalse);
    });
  });

  group('права администратора', () {
    const permissions = Permissions(UserRole.admin);

    test('может всё, что может менеджер', () {
      expect(permissions.canCreate, isTrue);
      expect(permissions.canUpdate, isTrue);
      expect(permissions.canSoftDelete, isTrue);
      expect(permissions.canBulkDelete, isTrue);
    });

    test('может физически удалять и восстанавливать', () {
      expect(permissions.canHardDelete, isTrue);
      expect(permissions.canRestore, isTrue);
      expect(permissions.canManageUsers, isTrue);
    });
  });

  group('гость', () {
    test('не получает доступ к внутреннему каталогу', () {
      const permissions = Permissions.guest();
      expect(permissions.canRead, isFalse);
      expect(permissions.canCreate, isFalse);
      expect(permissions.isAuthenticated, isFalse);
      expect(permissions.isGuest, isTrue);
    });

    test('гость отличается от вошедшего клиента', () {
      // У обоих роль client, но гость не выполнял вход.
      // Различие нужно, чтобы правильно объяснять ограничение.
      const guest = Permissions.guest();
      const client = Permissions(UserRole.client);
      expect(guest.role, client.role);
      expect(guest.isAuthenticated, isFalse);
      expect(client.isAuthenticated, isTrue);
    });
  });

  group('согласованность ролей', () {
    test('права только добавляются с ростом роли', () {
      const roles = [
        UserRole.client,
        UserRole.photographer,
        UserRole.manager,
        UserRole.admin,
      ];
      for (var i = 1; i < roles.length; i++) {
        final previous = Permissions(roles[i - 1]);
        final current = Permissions(roles[i]);
        expect(current.canRead, isTrue);
        // У клиента и фотографа прав на изменение нет.
        if (roles[i - 1] == UserRole.photographer) {
          expect(previous.canCreate, isFalse);
          expect(current.canCreate, isTrue);
        }
      }
    });
  });

  group('профиль пользователя', () {
    test('права выводятся из роли сервера', () {
      const user = AppUser(
        id: 1,
        username: 'manager',
        fullName: 'Руководитель смены',
        email: 'manager@focusframe.local',
        role: 'manager',
      );
      expect(user.roleLevel, UserRole.manager);
      expect(user.permissions.canCreate, isTrue);
      expect(user.permissions.canHardDelete, isFalse);
      expect(user.canManage, isTrue);
      expect(user.canAdminister, isFalse);
    });

    test('неизвестная роль не даёт лишних прав', () {
      const user = AppUser(
        id: 2,
        username: 'guest',
        fullName: 'Гость',
        email: 'guest@example.com',
        role: 'root',
      );
      expect(user.permissions.canCreate, isFalse);
      expect(user.permissions.canHardDelete, isFalse);
    });
  });
}
