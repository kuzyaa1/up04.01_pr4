#!/usr/bin/env node
/**
 * Проверка учебного API «Фотостудия FocusFrame» тем же способом, каким
 * с ним работает клиент на Flutter Web:
 *
 *   - чтение списка с пагинацией, поиском, фильтрами и сортировкой;
 *   - создание записи, получение ошибки 422 по полям;
 *   - ошибка 409 (конфликт);
 *   - ошибка 401 (нет токена) и 403 (не та роль);
 *   - логическое и физическое удаление, восстановление;
 *   - множественное удаление;
 *   - учебные переключатели ?__delay= и ?__fail=.
 *
 * Запуск:  node check-api.js
 */

'use strict';

const BASE = 'http://localhost:8080/api';

let passed = 0;
let failed = 0;

function check(name, condition, detail) {
  if (condition) {
    passed++;
    console.log(`  ✓ ${name}`);
  } else {
    failed++;
    console.log(`  ✗ ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

async function req(path, options = {}) {
  const response = await fetch(`${BASE}${path}`, {
    method: options.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  return { status: response.status, data };
}

async function main() {
  console.log('\n=== 1. Служебные адреса ===');
  const health = await req('/__health');
  check('GET /__health отвечает 200', health.status === 200, `статус ${health.status}`);

  console.log('\n=== 2. Аутентификация ===');
  const badLogin = await req('/auth/login', {
    method: 'POST',
    body: { username: 'manager', password: 'wrong' },
  });
  check('неверный пароль даёт 401', badLogin.status === 401, `статус ${badLogin.status}`);

  const login = await req('/auth/login', {
    method: 'POST',
    body: { username: 'manager', password: 'manager123' },
  });
  check('вход менеджера даёт 200', login.status === 200, `статус ${login.status}`);
  const token = login.data && login.data.accessToken;
  check('вход возвращает accessToken', Boolean(token));
  check('вход возвращает профиль пользователя', login.data?.user?.role === 'manager');

  const clientLogin = await req('/auth/login', {
    method: 'POST',
    body: { username: 'client', password: 'client123' },
  });
  const clientToken = clientLogin.data && clientLogin.data.accessToken;
  check('вход клиента даёт 200', clientLogin.status === 200);

  console.log('\n=== 3. Чтение списков ===');
  const halls = await req('/halls?page=1&size=3&sort=name,asc', { token });
  check('список залов отвечает 200', halls.status === 200);
  check('в ответе есть items', Array.isArray(halls.data?.items));
  check('размер страницы соблюдён', halls.data?.items?.length === 3, `пришло ${halls.data?.items?.length}`);
  check('в ответе есть total', typeof halls.data?.total === 'number');
  check('в ответе есть totalPages', typeof halls.data?.totalPages === 'number');
  check('в ответе есть номер страницы', halls.data?.page === 1);

  const sorted = await req('/halls?sort=capacity,desc&size=50', { token });
  const capacities = (sorted.data?.items || []).map((h) => h.capacity);
  const descending = capacities.every((v, i) => i === 0 || capacities[i - 1] >= v);
  check('сортировка по убыванию ёмкости соблюдена', descending, JSON.stringify(capacities));

  const filtered = await req('/halls?style=%D0%9B%D0%BE%D1%84%D1%82&size=50', { token });
  check(
    'фильтр по стилю оставляет только нужные залы',
    (filtered.data?.items || []).every((h) => h.style === 'Лофт'),
  );

  const searched = await req('/halls?search=%D1%86%D0%B8%D0%BA%D0%BB%D0%BE%D1%80%D0%B0%D0%BC%D0%B0&size=50', { token });
  check(
    'поиск по названию находит нужные залы',
    (searched.data?.items || []).length > 0 &&
      (searched.data?.items || []).every((h) =>
        `${h.name} ${h.code} ${h.style}`.toLowerCase().includes('циклорама'),
      ),
  );

  const paged = await req('/halls?page=2&size=3', { token });
  check('вторая страница отличается от первой', paged.data?.page === 2);
  check(
    'вторая страница содержит другие записи',
    JSON.stringify(paged.data?.items?.map((h) => h.id)) !==
      JSON.stringify(halls.data?.items?.map((h) => h.id)),
  );

  console.log('\n=== 4. Права доступа ===');
  const anonymous = await req('/halls');
  check('чтение каталога без токена разрешено', anonymous.status === 200, `статус ${anonymous.status}`);

  const anonymousWrite = await req('/halls', {
    method: 'POST',
    body: { name: 'X', code: 'X-1', style: 'Лофт', capacity: 1, hourlyRate: 1 },
  });
  check('создание без токена даёт 401', anonymousWrite.status === 401, `статус ${anonymousWrite.status}`);

  const clientWrite = await req('/halls', {
    method: 'POST',
    token: clientToken,
    body: { name: 'X', code: 'X-1', style: 'Лофт', capacity: 1, hourlyRate: 1 },
  });
  check('создание ролью клиента даёт 403', clientWrite.status === 403, `статус ${clientWrite.status}`);

  console.log('\n=== 5. Валидация 422 ===');
  const existing = await req('/halls?size=1', { token });
  const sample = existing.data.items[0];

  const duplicate = await req('/halls', {
    method: 'POST',
    token,
    body: {
      name: 'Дубль кода',
      code: sample.code,
      style: 'Лофт',
      capacity: 5,
      hourlyRate: 1000,
    },
  });
  check('повтор кода зала даёт 422', duplicate.status === 422, `статус ${duplicate.status}`);
  check('в ответе есть errors', Boolean(duplicate.data?.errors));
  check('ошибка привязана к полю code', Boolean(duplicate.data?.errors?.code), JSON.stringify(duplicate.data?.errors));

  const badYear = await req('/halls', {
    method: 'POST',
    token,
    body: { name: 'Плохая ёмкость', code: 'Z-99', style: 'Лофт', capacity: -5, hourlyRate: 1000 },
  });
  check('некорректная ёмкость даёт 422', badYear.status === 422, `статус ${badYear.status}`);
  check('ошибка привязана к полю capacity', Boolean(badYear.data?.errors?.capacity));

  console.log('\n=== 6. Создание, изменение, удаление ===');
  const created = await req('/halls', {
    method: 'POST',
    token,
    body: {
      name: 'Проверочный зал',
      code: 'TEST-01',
      style: 'Лофт',
      capacity: 7,
      hourlyRate: 1500,
      description: 'Создан проверкой',
    },
  });
  check('создание зала даёт 201', created.status === 201, `статус ${created.status}`);
  const newId = created.data?.id;
  check('в ответе есть идентификатор', typeof newId === 'number');
  check('присвоенный идентификатор возвращается', created.data?.id === newId);

  const updated = await req(`/halls/${newId}`, {
    method: 'PUT',
    token,
    body: {
      name: 'Проверочный зал (изменён)',
      code: 'TEST-01',
      style: 'Лофт',
      capacity: 9,
      hourlyRate: 1600,
    },
  });
  check('изменение зала даёт 200', updated.status === 200, `статус ${updated.status}`);
  check('изменения сохранены', updated.data?.capacity === 9 && updated.data?.name.includes('изменён'));

  const soft = await req(`/halls/${newId}`, { method: 'DELETE', token });
  check('логическое удаление даёт 204', soft.status === 204, `статус ${soft.status}`);

  const afterSoft = await req('/halls?size=100', { token });
  check(
    'удалённый зал скрыт из списка',
    !(afterSoft.data?.items || []).some((h) => h.id === newId),
  );

  const withDeleted = await req('/halls?includeDeleted=true&size=100', { token });
  check(
    'с параметром includeDeleted зал виден',
    (withDeleted.data?.items || []).some((h) => h.id === newId),
  );

  const adminLogin = await req('/auth/login', {
    method: 'POST',
    body: { username: 'admin', password: 'admin123' },
  });
  const adminToken = adminLogin.data.accessToken;

  const restore = await req(`/halls/${newId}/restore`, { method: 'POST', token: adminToken });
  check('восстановление даёт 200', restore.status === 200, `статус ${restore.status}`);

  const hard = await req(`/halls/${newId}?hard=true`, { method: 'DELETE', token: adminToken });
  check('физическое удаление даёт 204', hard.status === 204, `статус ${hard.status}`);

  const afterHard = await req('/halls?includeDeleted=true&size=100', { token: adminToken });
  check(
    'физически удалённый зал исчез совсем',
    !(afterHard.data?.items || []).some((h) => h.id === newId),
  );

  console.log('\n=== 7. Множественное удаление ===');
  const bulkIds = [];
  for (let i = 0; i < 3; i++) {
    const bulk = await req('/halls', {
      method: 'POST',
      token,
      body: {
        name: `Массовый ${i}`,
        code: `MASS-0${i}`,
        style: 'Лофт',
        capacity: 4,
        hourlyRate: 1000,
      },
    });
    bulkIds.push(bulk.data.id);
  }
  const bulk = await req('/halls/bulk-delete', { method: 'POST', token, body: { ids: bulkIds } });
  check('множественное удаление даёт 200', bulk.status === 200, `статус ${bulk.status}`);
  check('возвращено число удалённых записей', bulk.data?.deleted === 3, `пришло ${bulk.data?.deleted}`);

  console.log('\n=== 8. Конфликт 409 ===');
  const today = new Date().toISOString();
  const bookingClient = await req('/clients?size=1', { token });
  const clientId = bookingClient.data.items[0].id;
  const firstBooking = await req('/bookings', {
    method: 'POST',
    token,
    body: {
      accessCode: 'CHK-001',
      hallId: sample.id,
      clientId,
      photographerIds: [],
      date: today,
      durationHours: 2,
      participants: 2,
      shootingType: 'Портрет',
    },
  });
  check('создание бронирования даёт 201', firstBooking.status === 201, `статус ${firstBooking.status}`);

  const conflict = await req('/bookings', {
    method: 'POST',
    token,
    body: {
      accessCode: 'CHK-002',
      hallId: sample.id,
      clientId,
      photographerIds: [],
      date: today,
      durationHours: 2,
      participants: 2,
      shootingType: 'Портрет',
    },
  });
  check('повторное бронирование зала на ту же дату даёт 409', conflict.status === 409, `статус ${conflict.status}`);
  check('в ответе есть понятное сообщение', Boolean(conflict.data?.message));

  console.log('\n=== 9. Учебные переключатели ===');
  const failed500 = await req('/halls?__fail=500', { token });
  check('?__fail=500 даёт код 500', failed500.status === 500, `статус ${failed500.status}`);

  const delayed = await req('/halls?__delay=800', { token });
  check('?__delay=800 отвечает 200', delayed.status === 200);

  const reset = await req('/__reset', { method: 'POST' });
  check('сброс данных даёт 200', reset.status === 200);
  const afterReset = await req('/halls?size=100', { token });
  check('после сброса залов снова 8', afterReset.data?.total === 8, `пришло ${afterReset.data?.total}`);

  console.log(`\n=== Итог: успешно ${passed}, неудачно ${failed} ===\n`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((error) => {
  console.error('Проверка прервана:', error);
  process.exit(1);
});
