#!/usr/bin/env node
/**
 * Мок-сервер учебного API «Фотостудия FocusFrame».
 *
 * Реализует контракт, согласованный с учебным API «Библиотека»:
 *   - адрес:            http://localhost:8080/api
 *   - пагинация:        { items, page, size, total, totalPages }
 *   - ошибки:           { message } и { message, errors } для 422
 *   - роли:             reader / photographer / manager / admin
 *   - CORS:             разрешённый источник + обработчик OPTIONS
 *
 * Зависимостей нет — нужен только Node.js 18 или новее.
 *
 *   node mock-server.js
 *   node mock-server.js --port 8080 --origin http://localhost:5555
 *
 * Данные хранятся в памяти и сбрасываются при перезапуске
 * либо запросом POST /api/__reset
 *
 * Учебные возможности:
 *   ?__delay=1500   задержка ответа в миллисекундах (проверка индикатора загрузки)
 *   ?__fail=500     принудительный код ошибки (проверка обработки ошибок)
 */

'use strict';

const http = require('node:http');
const crypto = require('node:crypto');

// ─────────────────────────── параметры запуска ───────────────────────────

const args = process.argv.slice(2);
function arg(name, fallback) {
  const i = args.indexOf('--' + name);
  return i !== -1 && args[i + 1] ? args[i + 1] : fallback;
}

const PORT = Number(arg('port', 8080));
const ORIGIN = arg('origin', '*');
const SECRET = 'учебный-ключ-фотостудии-не-для-продакшена';
const ACCESS_TTL = Number(arg('ttl', 900)); // секунд
const REFRESH_TTL = 60 * 60 * 24 * 7;

// ─────────────────────────────── токены ───────────────────────────────

function b64url(buf) {
  return Buffer.from(buf).toString('base64url');
}

function sign(payload) {
  // jti делает каждый токен уникальным. Без него два токена, выпущенные
  // в одну и ту же секунду для одного пользователя, совпадут побайтово,
  // и отзыв старого токена обновления отзовёт заодно и новый.
  const withId = { ...payload, jti: crypto.randomUUID() };
  const body = b64url(JSON.stringify(withId));
  const mac = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return body + '.' + mac;
}

function verify(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const [body, mac] = token.split('.');
  const expected = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  if (mac !== expected) return null;
  let payload;
  try {
    payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    return null;
  }
  if (payload.exp && payload.exp * 1000 < Date.now()) return null;
  return payload;
}

// ─────────────────────────────── данные ───────────────────────────────

let db;

function iso(y, m, d) {
  return new Date(Date.UTC(y, m - 1, d)).toISOString();
}

function hash(password) {
  return crypto.createHash('sha256').update(password + SECRET).digest('hex');
}

function push(collection, obj) {
  db.seq[collection] = (db.seq[collection] || 0) + 1;
  const id = db.seq[collection];
  db[collection].push({ id, ...obj, createdAt: new Date().toISOString(), deletedAt: null });
  return id;
}

function seed() {
  db = {
    seq: {},
    halls: [],
    photographers: [],
    clients: [],
    equipment: [],
    bookings: [],
    users: [],
    refreshTokens: new Set(),
  };

  // ── Залы студии ──
  const H = (name, code, style, capacity, hourlyRate, description) =>
    push('halls', { name, code, style, capacity, hourlyRate, description });

  const whiteCyclorama = H('Белая циклорама', 'A-01', 'Циклорама', 8, 2500, 'Зал с белым циклорамным фоном');
  const loftFactory = H('Loft Factory', 'A-02', 'Лофт', 12, 3200, 'Индустриальный лофт с кирпичной стеной');
  const scandinavia = H('Скандинавия', 'B-01', 'Интерьерный', 6, 2800, 'Светлый зал в скандинавском стиле');
  const blackRoom = H('Black Room', 'B-02', 'Тёмный зал', 5, 2700, 'Полностью чёрный зал для драматичных кадров');
  const greenhouse = H('Оранжерея', 'C-01', 'Дневной свет', 10, 3500, 'Зал с растениями и мягким дневным светом');
  const minimal = H('Minimal', 'C-02', 'Циклорама', 4, 2100, 'Минималистичный зал в оттенках серого');
  const brickMetal = H('Кирпич и металл', 'D-01', 'Лофт', 14, 3900, 'Зал с кирпичными стенами и металлическими фермами');
  const daylight = H('Daylight', 'D-02', 'Дневной свет', 16, 4200, 'Просторный зал с панорамными окнами');

  // ── Фотографы ──
  const P = (fullName, specialization, city, birthYear, experienceYears, hourlyRate) =>
    push('photographers', { fullName, specialization, city, birthYear, experienceYears, hourlyRate });

  const tolstoy = P('Иванова Мария Петровна', 'Портрет', 'Москва', 1988, 12, 4500);
  const sidorov = P('Сидоров Алексей Николаевич', 'Семейная съёмка', 'Москва', 1990, 9, 3800);
  const kuznetsova = P('Кузнецова Ольга Викторовна', 'Предметная съёмка', 'Санкт-Петербург', 1985, 15, 5200);
  const orlov = P('Орлов Деник Сергеевич', 'Fashion', 'Москва', 1992, 7, 4000);
  const petrova = P('Петрова Анна Игоревна', 'Контент для брендов', 'Казань', 1987, 11, 4700);
  const smirnov = P('Смирнов Артём Львович', 'Портрет', 'Москва', 1995, 5, 3200);
  const voronina = P('Воронина Екатерина Юрьевна', 'Семейная съёмка', 'Екатеринбург', 1991, 8, 3600);

  // ── Оборудование ──
  const E = (name, category, manufacturer, hallId, quantity, pricePerDay) =>
    push('equipment', { name, category, manufacturer, hallId, quantity, pricePerDay });

  E('Световой набор Profoto', 'Свет', 'Profoto', whiteCyclorama, 2, 4500);
  E('Циклорама 6 м', 'Фоны', 'Profoto', whiteCyclorama, 1, 12000);
  E('Софтбокс 120 см', 'Свет', 'Aputure', loftFactory, 3, 3200);
  E('Деревянный стол', 'Мебель', 'Икеа', loftFactory, 4, 1800);
  E('Портретный отражатель', 'Свет', 'Broncolor', scandinavia, 2, 2400);
  E('Растение в кашпо', 'Реквизит', 'Дом и сад', greenhouse, 6, 900);
  E('Студийный стол', 'Мебель', 'Икеа', minimal, 1, 2200);
  E('Фон хром', 'Фоны', 'Fola', minimal, 2, 3800);
  E('Манекен', 'Реквизит', 'Mannequin', blackRoom, 2, 6500);
  E('RGB-панель', 'Свет', 'Nanlite', daylight, 4, 5100);
  E('Кресло', 'Мебель', 'IKEA', daylight, 2, 1500);

  // ── Клиенты ──
  const C = (fullName, email, phone, clientType, company, cardNumber, issuedAt, expiresAt) =>
    push('clients', {
      fullName, email, phone, clientType, company,
      cardNumber, cardIssuedAt: issuedAt, cardExpiresAt: expiresAt,
    });

  C('Смирнов Пётр Алексеевич', 'smirnov@example.com', '+7 900 100-10-01', 'Частный', '', 'FF-000001', iso(2026, 1, 15), iso(2027, 1, 15));
  C('Кузнецова Мария Ивановна', 'kuznetsova@example.com', '+7 900 100-10-02', 'Корпоративный', 'Студия «Кадр»', 'FF-000002', iso(2026, 1, 16), iso(2027, 1, 16));
  C('Попов Дмитрий Сергеевич', 'popov@example.com', '+7 900 100-10-03', 'Частный', '', 'FF-000003', iso(2026, 1, 17), iso(2027, 1, 17));
  C('Васильева Елена Олеговна', 'vasileva@example.com', '+7 900 100-10-04', 'Корпоративный', 'Маркетинг-отдел «Вектор»', 'FF-000004', iso(2026, 1, 18), iso(2027, 1, 18));
  C('Новиков Андрей Викторович', 'novikov@example.com', '+7 900 100-10-05', 'Частный', '', 'FF-000005', iso(2026, 1, 19), iso(2027, 1, 19));
  C('Морозова Татьяна Николаевна', 'morozova@example.com', '+7 900 100-10-06', 'Корпоративный', 'Агентство «Пятно»', 'FF-000006', iso(2026, 1, 20), iso(2027, 1, 20));

  // ── Бронирования ──
  // status: active | completed | cancelled
  const B = (hallId, clientId, photographerIds, date, durationHours, participants, shootingType, comment, status, accessCode) =>
    push('bookings', {
      hallId, clientId, photographerIds, date, durationHours, participants,
      shootingType, comment, status, accessCode,
    });

  const daysAgo = (n) => new Date(Date.now() - n * 86400000).toISOString();
  const daysAhead = (n) => new Date(Date.now() + n * 86400000).toISOString();

  B(whiteCyclorama, 1, [tolstoy], daysAgo(20), 3, 2, 'Портрет', 'Предметная съёмка для каталога', 'completed', 'BR-1001');
  B(loftFactory, 2, [sidorov], daysAgo(5), 4, 8, 'Семейная съёмка', 'Семейный портрет', 'completed', 'BR-1002');
  B(greenhouse, 3, [petrova], daysAgo(30), 2, 1, 'Контент для брендов', 'Съёмка для соцсетей', 'cancelled', 'BR-1003');
  B(blackRoom, 4, [kuznetsova], daysAhead(3), 5, 3, 'Fashion', 'Кампейн к весеннему каталогу', 'active', 'BR-1004');
  B(whiteCyclorama, 1, [tolstoy, smirnov], daysAhead(7), 2, 4, 'Портрет', 'Съёмка резюме', 'active', 'BR-1005');
  B(scandinavia, 5, [voronina], daysAhead(10), 3, 6, 'Семейная съёмка', 'Юбилей семьи', 'active', 'BR-1006');
  B(daylight, 2, [orlov], daysAhead(14), 6, 10, 'Fashion', 'Показ коллекции', 'active', 'BR-1007');
  B(minimal, 3, [kuznetsova], daysAgo(2), 1, 1, 'Предметная съёмка', 'Кадры для маркетплейса', 'active', 'BR-1008');
  B(brickMetal, 6, [petrova, sidorov], daysAhead(21), 4, 12, 'Контент для брендов', 'Съёмка интерьера офиса', 'active', 'BR-1009');
  B(greenhouse, 1, [smirnov], daysAhead(28), 2, 2, 'Портрет', 'Портрет в естественном свете', 'active', 'BR-1010');

  // ── Пользователи ──
  push('users', {
    username: 'admin', passwordHash: hash('admin123'), fullName: 'Администратор студии',
    email: 'admin@focusframe.local', role: 'admin', clientId: null,
  });
  push('users', {
    username: 'manager', passwordHash: hash('manager123'), fullName: 'Руководитель смены',
    email: 'manager@focusframe.local', role: 'manager', clientId: null,
  });
  push('users', {
    username: 'photographer', passwordHash: hash('photographer123'), fullName: 'Иванова Мария Петровна',
    email: 'ivanova@focusframe.local', role: 'photographer', clientId: null,
  });
  push('users', {
    username: 'client', passwordHash: hash('client123'), fullName: 'Смирнов Пётр Алексеевич',
    email: 'smirnov@example.com', role: 'client', clientId: 1,
  });
}

// ──────────────────────── развёртывание объектов ────────────────────────

function slimName(obj) {
  return obj ? { id: obj.id, name: obj.name } : null;
}

function expandHall(h) {
  const photographerIds = db.bookings
    .filter((b) => b.hallId === h.id && !b.deletedAt)
    .flatMap((b) => b.photographerIds);
  const uniquePhotographers = [...new Set(photographerIds)];
  return {
    id: h.id,
    name: h.name,
    code: h.code,
    style: h.style,
    capacity: h.capacity,
    hourlyRate: h.hourlyRate,
    description: h.description,
    equipmentIds: db.equipment
      .filter((e) => e.hallId === h.id && !e.deletedAt)
      .map((e) => e.id),
    photographerIds: uniquePhotographers,
    activeBookings: db.bookings.filter(
      (b) => b.hallId === h.id && b.status === 'active' && !b.deletedAt,
    ).length,
    createdAt: h.createdAt,
    deletedAt: h.deletedAt,
  };
}

function expandPhotographer(p) {
  const bookings = db.bookings.filter(
    (b) => b.photographerIds.includes(p.id) && !b.deletedAt,
  );
  return {
    id: p.id,
    fullName: p.fullName,
    specialization: p.specialization,
    city: p.city,
    birthYear: p.birthYear,
    experienceYears: p.experienceYears,
    hourlyRate: p.hourlyRate,
    bookingIds: bookings.map((b) => b.id),
    activeBookings: bookings.filter((b) => b.status === 'active').length,
    createdAt: p.createdAt,
    deletedAt: p.deletedAt,
  };
}

function expandClient(c) {
  const bookings = db.bookings.filter((b) => b.clientId === c.id && !b.deletedAt);
  return {
    id: c.id,
    fullName: c.fullName,
    email: c.email,
    phone: c.phone,
    clientType: c.clientType,
    company: c.company,
    card: c.cardNumber
      ? {
          number: c.cardNumber,
          issuedAt: c.cardIssuedAt,
          expiresAt: c.cardExpiresAt,
        }
      : null,
    bookingIds: bookings.map((b) => b.id),
    activeBookings: bookings.filter((b) => b.status === 'active').length,
    createdAt: c.createdAt,
    deletedAt: c.deletedAt,
  };
}

function expandEquipment(e) {
  return {
    id: e.id,
    name: e.name,
    category: e.category,
    manufacturer: e.manufacturer,
    hallId: e.hallId,
    hall: slimName(db.halls.find((h) => h.id === e.hallId)),
    quantity: e.quantity,
    pricePerDay: e.pricePerDay,
    createdAt: e.createdAt,
    deletedAt: e.deletedAt,
  };
}

function expandBooking(b) {
  const hall = db.halls.find((h) => h.id === b.hallId);
  const client = db.clients.find((c) => c.id === b.clientId);
  return {
    id: b.id,
    accessCode: b.accessCode,
    hall: hall ? { id: hall.id, name: hall.name, code: hall.code } : null,
    client: client ? { id: client.id, fullName: client.fullName } : null,
    photographerIds: b.photographerIds,
    photographers: b.photographerIds
      .map((id) => db.photographers.find((p) => p.id === id))
      .filter(Boolean)
      .map((p) => ({ id: p.id, fullName: p.fullName })),
    date: b.date,
    durationHours: b.durationHours,
    participants: b.participants,
    shootingType: b.shootingType,
    comment: b.comment,
    status: b.status,
    createdAt: b.createdAt,
    deletedAt: b.deletedAt,
  };
}

const EXPANDERS = {
  halls: expandHall,
  photographers: expandPhotographer,
  clients: expandClient,
  equipment: expandEquipment,
  bookings: expandBooking,
};

// ─────────────────────────── общие операции ───────────────────────────

function searchableText(collection, item) {
  switch (collection) {
    case 'halls':
      return [item.name, item.code, item.style, item.description].join(' ');
    case 'photographers':
      return [item.fullName, item.specialization, item.city].join(' ');
    case 'clients':
      return [item.fullName, item.email, item.phone, item.company].join(' ');
    case 'equipment':
      return [item.name, item.category, item.manufacturer].join(' ');
    case 'bookings':
      return [
        item.accessCode,
        item.shootingType,
        item.comment,
        db.halls.find((h) => h.id === item.hallId)?.name ?? '',
        db.clients.find((c) => c.id === item.clientId)?.fullName ?? '',
      ].join(' ');
    default:
      return '';
  }
}

function applyFilters(collection, rows, q) {
  let result = rows;

  if (q.search) {
    const needle = String(q.search).toLowerCase();
    result = result.filter((x) =>
      searchableText(collection, x).toLowerCase().includes(needle),
    );
  }

  if (collection === 'halls') {
    if (q.style) result = result.filter((h) => h.style === q.style);
    if (q.capacityFrom) result = result.filter((h) => h.capacity >= Number(q.capacityFrom));
    if (q.capacityTo) result = result.filter((h) => h.capacity <= Number(q.capacityTo));
    if (q.priceFrom) result = result.filter((h) => h.hourlyRate >= Number(q.priceFrom));
    if (q.priceTo) result = result.filter((h) => h.hourlyRate <= Number(q.priceTo));
  }

  if (collection === 'photographers') {
    if (q.specialization) {
      result = result.filter((p) => p.specialization === q.specialization);
    }
    if (q.city) result = result.filter((p) => p.city === q.city);
    if (q.experienceFrom) {
      result = result.filter((p) => p.experienceYears >= Number(q.experienceFrom));
    }
    if (q.experienceTo) {
      result = result.filter((p) => p.experienceYears <= Number(q.experienceTo));
    }
    if (q.rateFrom) result = result.filter((p) => p.hourlyRate >= Number(q.rateFrom));
    if (q.rateTo) result = result.filter((p) => p.hourlyRate <= Number(q.rateTo));
  }

  if (collection === 'clients') {
    if (q.clientType) result = result.filter((c) => c.clientType === q.clientType);
    if (q.hasCard === 'true') {
      result = result.filter((c) => Boolean(c.cardNumber && c.cardNumber.trim()));
    }
    if (q.hasCard === 'false') {
      result = result.filter((c) => !c.cardNumber || !c.cardNumber.trim());
    }
    if (q.yearFrom || q.yearTo) {
      result = result.filter((c) => {
        const year = Number((c.cardIssuedAt || '').slice(0, 4)) || 0;
        if (year === 0) return !q.yearFrom && !q.yearTo;
        if (q.yearFrom && year < Number(q.yearFrom)) return false;
        if (q.yearTo && year > Number(q.yearTo)) return false;
        return true;
      });
    }
  }

  if (collection === 'equipment') {
    if (q.category) result = result.filter((e) => e.category === q.category);
    if (q.hallId) result = result.filter((e) => e.hallId === Number(q.hallId));
    if (q.quantityFrom) {
      result = result.filter((e) => e.quantity >= Number(q.quantityFrom));
    }
    if (q.quantityTo) result = result.filter((e) => e.quantity <= Number(q.quantityTo));
    if (q.priceFrom) {
      result = result.filter((e) => e.pricePerDay >= Number(q.priceFrom));
    }
    if (q.priceTo) result = result.filter((e) => e.pricePerDay <= Number(q.priceTo));
  }

  if (collection === 'bookings') {
    if (q.hallId) result = result.filter((b) => b.hallId === Number(q.hallId));
    if (q.clientId) result = result.filter((b) => b.clientId === Number(q.clientId));
    if (q.photographerId) {
      result = result.filter((b) => b.photographerIds.includes(Number(q.photographerId)));
    }
    if (q.shootingType) {
      result = result.filter((b) => b.shootingType === q.shootingType);
    }
    if (q.status) result = result.filter((b) => b.status === q.status);
    if (q.participantsFrom) {
      result = result.filter((b) => b.participants >= Number(q.participantsFrom));
    }
    if (q.participantsTo) {
      result = result.filter((b) => b.participants <= Number(q.participantsTo));
    }
    if (q.durationFrom) {
      result = result.filter((b) => b.durationHours >= Number(q.durationFrom));
    }
    if (q.durationTo) {
      result = result.filter((b) => b.durationHours <= Number(q.durationTo));
    }
    if (q.dateFrom) {
      const from = Date.parse(q.dateFrom);
      if (!Number.isNaN(from)) {
        result = result.filter((b) => Date.parse(b.date) >= from);
      }
    }
    if (q.dateTo) {
      const to = Date.parse(q.dateTo);
      if (!Number.isNaN(to)) {
        result = result.filter((b) => Date.parse(b.date) <= to);
      }
    }
  }

  return result;
}

function applySort(rows, sort) {
  if (!sort) return rows;
  const [field, dirRaw] = String(sort).split(',');
  const dir = (dirRaw || 'asc').toLowerCase() === 'desc' ? -1 : 1;
  return [...rows].sort((a, b) => {
    const av = a[field];
    const bv = b[field];
    if (av == null && bv == null) return 0;
    if (av == null) return 1;
    if (bv == null) return -1;
    if (typeof av === 'number' && typeof bv === 'number') return (av - bv) * dir;
    return String(av).localeCompare(String(bv), 'ru') * dir;
  });
}

function paginate(rows, q) {
  const page = Math.max(1, Number(q.page) || 1);
  const size = Math.min(100, Math.max(1, Number(q.size) || 10));
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / size));
  return {
    items: rows.slice((page - 1) * size, page * size),
    page,
    size,
    total,
    totalPages,
  };
}

// ─────────────────────────────── валидация ───────────────────────────────

function validate(collection, body, id = null) {
  const e = {};
  const str = (v) => (typeof v === 'string' ? v.trim() : '');

  if (collection === 'halls') {
    if (!str(body.name)) e.name = 'Укажите название зала';
    else if (str(body.name).length > 120) e.name = 'Не длиннее 120 символов';

    if (!str(body.code)) e.code = 'Укажите код зала';
    else {
      const dup = db.halls.find(
        (h) => h.code.toUpperCase() === str(body.code).toUpperCase() && h.id !== id && !h.deletedAt,
      );
      if (dup) e.code = 'Зал с таким кодом уже существует';
    }

    if (!str(body.style)) e.style = 'Укажите стиль съёмки';

    const capacity = Number(body.capacity);
    if (!Number.isInteger(capacity) || capacity < 1) {
      e.capacity = 'Вместимость — положительное целое число';
    }

    const rate = Number(body.hourlyRate);
    if (!Number.isInteger(rate) || rate < 0) {
      e.hourlyRate = 'Цена за час — целое неотрицательное число';
    }
  }

  if (collection === 'photographers') {
    if (!str(body.fullName)) e.fullName = 'Укажите ФИО фотографа';
    if (!str(body.specialization)) e.specialization = 'Укажите специализацию';
    if (body.experienceYears != null) {
      const y = Number(body.experienceYears);
      if (!Number.isInteger(y) || y < 0 || y > 80) {
        e.experienceYears = 'Некорректное число лет опыта';
      }
    }
    if (body.hourlyRate != null) {
      const r = Number(body.hourlyRate);
      if (!Number.isInteger(r) || r < 0) {
        e.hourlyRate = 'Ставка — целое неотрицательное число';
      }
    }
  }

  if (collection === 'clients') {
    if (!str(body.fullName)) e.fullName = 'Укажите ФИО клиента';
    if (!str(body.email)) e.email = 'Укажите адрес почты';
    else if (!/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(str(body.email))) {
      e.email = 'Некорректный адрес почты';
    } else {
      const dup = db.clients.find(
        (c) => c.email.toLowerCase() === str(body.email).toLowerCase() && c.id !== id && !c.deletedAt,
      );
      if (dup) e.email = 'Клиент с такой почтой уже зарегистрирован';
    }
    if (str(body.phone)) {
      const dup = db.clients.find(
        (c) => c.phone.trim() === str(body.phone).trim() && c.id !== id && !c.deletedAt,
      );
      if (dup) e.phone = 'Клиент с таким телефоном уже есть';
    }
    if (str(body.cardNumber)) {
      const dup = db.clients.find(
        (c) => c.cardNumber.trim().toUpperCase() === str(body.cardNumber).trim().toUpperCase() &&
          c.id !== id && !c.deletedAt,
      );
      if (dup) e.cardNumber = 'Абонемент с таким номером уже есть';
    }
  }

  if (collection === 'equipment') {
    if (!str(body.name)) e.name = 'Укажите название оборудования';
    else if (str(body.name).length > 120) e.name = 'Не длиннее 120 символов';
    if (!str(body.category)) e.category = 'Укажите категорию';
    if (body.hallId != null && !db.halls.find((h) => h.id === Number(body.hallId) && !h.deletedAt)) {
      e.hallId = 'Зал не найден';
    }
    const quantity = Number(body.quantity);
    if (!Number.isInteger(quantity) || quantity < 0) {
      e.quantity = 'Количество — целое неотрицательное число';
    }
    const price = Number(body.pricePerDay);
    if (!Number.isInteger(price) || price < 0) {
      e.pricePerDay = 'Цена — целое неотрицательное число';
    }
  }

  if (collection === 'bookings') {
    if (!str(body.accessCode)) e.accessCode = 'Укажите код бронирования';
    else {
      const dup = db.bookings.find(
        (b) => b.accessCode.trim().toUpperCase() === str(body.accessCode).toUpperCase() &&
          b.id !== id && !b.deletedAt,
      );
      if (dup) e.accessCode = 'Бронирование с таким кодом уже существует';
    }

    if (body.hallId != null && !db.halls.find((h) => h.id === Number(body.hallId) && !h.deletedAt)) {
      e.hallId = 'Зал не найден';
    }
    if (body.clientId != null && !db.clients.find((c) => c.id === Number(body.clientId) && !c.deletedAt)) {
      e.clientId = 'Клиент не найден';
    }

    if (body.date) {
      const d = Date.parse(body.date);
      if (Number.isNaN(d)) e.date = 'Некорректная дата съёмки';
    }

    const duration = Number(body.durationHours);
    if (!Number.isInteger(duration) || duration < 1 || duration > 24) {
      e.durationHours = 'Длительность — от 1 до 24 часов';
    }

    const participants = Number(body.participants);
    if (!Number.isInteger(participants) || participants < 1) {
      e.participants = 'Участников должно быть не меньше одного';
    }

    if (!str(body.shootingType)) e.shootingType = 'Укажите тип съёмки';
  }

  return e;
}

// ──────────────────────────── HTTP-обвязка ────────────────────────────

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
  res.setHeader('Vary', 'Origin');
}

function send(res, status, payload) {
  cors(res);
  if (payload === undefined || status === 204) {
    res.writeHead(204);
    res.end();
    return;
  }
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
  });
  res.end(body);
}

function fail(res, status, message) {
  send(res, status, { message });
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch {
    return null; // признак некорректного JSON
  }
}

function currentUser(req) {
  const header = req.headers['authorization'] || '';
  if (!header.startsWith('Bearer ')) return null;
  const payload = verify(header.slice(7));
  if (!payload || payload.type !== 'access') return null;
  return db.users.find((u) => u.id === payload.sub && !u.deletedAt) || null;
}

const ROLE_LEVEL = { client: 1, photographer: 2, manager: 3, admin: 4 };

function requireRole(res, user, minRole) {
  if (!user) {
    fail(res, 401, 'Требуется аутентификация');
    return false;
  }
  if (ROLE_LEVEL[user.role] < ROLE_LEVEL[minRole]) {
    fail(res, 403, `Операция доступна начиная с роли «${minRole}»`);
    return false;
  }
  return true;
}

const COLLECTIONS = ['halls', 'photographers', 'clients', 'equipment', 'bookings'];

// ─────────────────────────────── маршруты ───────────────────────────────

async function handle(req, res, url) {
  const q = Object.fromEntries(url.searchParams.entries());
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = req.method.toUpperCase();
  const user = currentUser(req);

  // Учебные переключатели поведения
  if (q.__fail) {
    return fail(res, Number(q.__fail), 'Ошибка вызвана намеренно параметром __fail');
  }

  // ── служебные ──
  if (path === '/api/__reset' && method === 'POST') {
    seed();
    return send(res, 200, { message: 'Данные восстановлены в исходное состояние' });
  }

  if (path === '/api/__health' && method === 'GET') {
    return send(res, 200, { status: 'ok', service: 'focusframe', time: new Date().toISOString() });
  }

  // Справочник адресов. Нужен, чтобы при открытии http://localhost:8080/api
  // в браузере было видно, что сервер работает и какие у него адреса,
  // а не сообщение об ошибке.
  if ((path === '/api' || path === '/api/') && method === 'GET') {
    return send(res, 200, {
      service: 'Учебное API «Фотостудия FocusFrame»',
      version: '1.0',
      time: new Date().toISOString(),
      collections: COLLECTIONS,
      endpoints: {
        'POST /api/auth/login': 'Вход: { username, password } → { accessToken, refreshToken, user }',
        'GET /api/auth/me': 'Текущий пользователь по токену',
        'GET /api/:collection': 'Список записей с поиском, фильтрами, сортировкой и страницами',
        'GET /api/:collection/{id}': 'Одна запись',
        'POST /api/:collection': 'Создать запись (роль manager и выше)',
        'PUT /api/:collection/{id}': 'Изменить запись (роль manager и выше)',
        'DELETE /api/:collection/{id}': 'Логическое удаление (роль manager и выше)',
        'DELETE /api/:collection/{id}?hard=true': 'Физическое удаление (роль admin)',
        'POST /api/:collection/bulk-delete': 'Множественное удаление: { ids: [...] }',
        'POST /api/:collection/{id}/restore': 'Восстановить запись (роль admin)',
        'POST /api/bookings/{id}/cancel': 'Отменить бронирование',
        'POST /api/bookings/{id}/complete': 'Завершить бронирование',
        'GET /api/__health': 'Проверка живости сервера',
        'POST /api/__reset': 'Сброс данных в исходное состояние',
      },
      queryParameters: {
        search: 'Поиск по нескольким полям сущности',
        sort: 'Сортировка, например name,asc или year,desc',
        page: 'Номер страницы, с 1',
        size: 'Размер страницы, до 100',
        includeDeleted: 'true — показать удалённые записи',
      },
      accounts: [
        { username: 'admin', password: 'admin123', role: 'admin' },
        { username: 'manager', password: 'manager123', role: 'manager' },
        { username: 'photographer', password: 'photographer123', role: 'photographer' },
        { username: 'client', password: 'client123', role: 'client' },
      ],
      teachingSwitches: {
        '?__delay=1500': 'задержка ответа на 1,5 с — проверка индикатора загрузки',
        '?__fail=500': 'принудительный код ошибки — проверка состояния ошибки',
      },
    });
  }

  // ── аутентификация ──
  if (path === '/api/auth/register' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const username = String(body.username || '').trim();
    const password = String(body.password || '');
    if (username.length < 3) errors.username = 'Логин не короче трёх символов';
    else if (db.users.find((u) => u.username === username)) errors.username = 'Такой логин уже занят';
    if (password.length < 8) errors.password = 'Пароль не короче восьми символов';
    else if (!/\d/.test(password)) errors.password = 'Пароль должен содержать цифру';
    if (body.email && !/^[\w.+-]+@[\w-]+\.[\w.-]+$/.test(String(body.email))) {
      errors.email = 'Некорректный адрес почты';
    }

    if (Object.keys(errors).length) {
      return send(res, 422, { message: 'Ошибка валидации', errors });
    }

    const id = push('users', {
      username,
      passwordHash: hash(password),
      fullName: String(body.fullName || username),
      email: String(body.email || ''),
      role: 'client',
      clientId: null,
    });
    return send(res, 201, expandUser(db.users.find((u) => u.id === id)));
  }

  if (path === '/api/auth/login' && method === 'POST') {
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const found = db.users.find(
      (u) => u.username === String(body.username || '').trim() && !u.deletedAt,
    );
    if (!found || found.passwordHash !== hash(String(body.password || ''))) {
      return fail(res, 401, 'Неверный логин или пароль');
    }

    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);

    return send(res, 200, {
      accessToken,
      refreshToken,
      expiresIn: ACCESS_TTL,
      user: expandUser(found),
    });
  }

  if (path === '/api/auth/refresh' && method === 'POST') {
    const body = await readBody(req);
    const token = body && body.refreshToken;
    const payload = verify(token);
    if (!payload || payload.type !== 'refresh' || !db.refreshTokens.has(token)) {
      return fail(res, 401, 'Токен обновления недействителен');
    }
    const found = db.users.find((u) => u.id === payload.sub);
    if (!found) return fail(res, 401, 'Пользователь не найден');

    db.refreshTokens.delete(token);
    const now = Math.floor(Date.now() / 1000);
    const accessToken = sign({ sub: found.id, role: found.role, type: 'access', exp: now + ACCESS_TTL });
    const refreshToken = sign({ sub: found.id, type: 'refresh', exp: now + REFRESH_TTL });
    db.refreshTokens.add(refreshToken);

    return send(res, 200, { accessToken, refreshToken, expiresIn: ACCESS_TTL, user: expandUser(found) });
  }

  if (path === '/api/auth/me' && method === 'GET') {
    if (!user) return fail(res, 401, 'Требуется аутентификация');
    return send(res, 200, expandUser(user));
  }

  if (path === '/api/auth/logout' && method === 'POST') {
    const body = await readBody(req);
    if (body && body.refreshToken) db.refreshTokens.delete(body.refreshToken);
    return send(res, 204);
  }

  // ── управление пользователями (только admin) ──
  if (path === '/api/users' && method === 'GET') {
    if (!requireRole(res, user, 'admin')) return;
    const rows = applySort(db.users.filter((u) => !u.deletedAt), q.sort);
    const page = paginate(rows, q);
    return send(res, 200, { ...page, items: page.items.map(expandUser) });
  }

  // ── специальные операции с бронированиями ──
  if (path === '/api/bookings' && method === 'POST') {
    if (!requireRole(res, user, 'manager')) return;
    const body = await readBody(req);
    if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

    const errors = {};
    const client = db.clients.find((c) => c.id === Number(body.clientId) && !c.deletedAt);
    const hall = db.halls.find((h) => h.id === Number(body.hallId) && !h.deletedAt);
    if (!client) errors.clientId = 'Клиент не найден';
    if (!hall) errors.hallId = 'Зал не найден';
    if (Object.keys(errors).length) {
      return send(res, 422, { message: 'Ошибка валидации', errors });
    }

    // Конфликт: в зале уже стоит бронирование на ту же дату.
    const sameDay = db.bookings.some(
      (b) =>
        b.hallId === hall.id &&
        b.status === 'active' &&
        !b.deletedAt &&
        new Date(b.date).toDateString() === new Date(body.date).toDateString(),
    );
    if (sameDay) {
      return fail(res, 409, 'На эту дату в зале уже есть активное бронирование');
    }

    const id = push('bookings', normalize('bookings', body));
    return send(res, 201, expandBooking(db.bookings.find((b) => b.id === id)));
  }

  let m = path.match(/^\/api\/bookings\/(\d+)\/cancel$/);
  if (m && method === 'POST') {
    if (!requireRole(res, user, 'manager')) return;
    const booking = db.bookings.find((b) => b.id === Number(m[1]) && !b.deletedAt);
    if (!booking) return fail(res, 404, 'Бронирование не найдено');
    if (booking.status !== 'active') {
      return fail(res, 409, 'Отменить можно только активное бронирование');
    }
    booking.status = 'cancelled';
    return send(res, 200, expandBooking(booking));
  }

  m = path.match(/^\/api\/bookings\/(\d+)\/complete$/);
  if (m && method === 'POST') {
    if (!requireRole(res, user, 'manager')) return;
    const booking = db.bookings.find((b) => b.id === Number(m[1]) && !b.deletedAt);
    if (!booking) return fail(res, 404, 'Бронирование не найдено');
    if (booking.status !== 'active') {
      return fail(res, 409, 'Завершить можно только активное бронирование');
    }
    booking.status = 'completed';
    return send(res, 200, expandBooking(booking));
  }

  // ── единообразный CRUD ──
  const bulk = path.match(/^\/api\/([a-z]+)\/bulk-delete$/);

  if (bulk && method === 'POST') {
    const collection = bulk[1];
    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    if (!requireRole(res, user, 'manager')) return;

    const body = await readBody(req);
    const ids = Array.isArray(body && body.ids) ? body.ids.map(Number) : [];
    if (!ids.length) {
      return send(res, 422, {
        message: 'Ошибка валидации',
        errors: { ids: 'Передайте непустой список идентификаторов' },
      });
    }

    let deleted = 0;
    for (const row of db[collection]) {
      if (ids.includes(row.id) && !row.deletedAt) {
        row.deletedAt = new Date().toISOString();
        deleted += 1;
      }
    }
    return send(res, 200, { deleted });
  }

  m = path.match(/^\/api\/([a-z]+)(?:\/(\d+))?(?:\/(restore))?$/);

  if (m) {
    const collection = m[1];
    const id = m[2] ? Number(m[2]) : null;
    const action = m[3] || null;

    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    const expand = EXPANDERS[collection];

    // восстановление
    if (action === 'restore' && method === 'POST') {
      if (!requireRole(res, user, 'admin')) return;
      const row = db[collection].find((x) => x.id === id);
      if (!row) return fail(res, 404, 'Объект не найден');
      row.deletedAt = null;
      return send(res, 200, expand(row));
    }

    // список
    if (id === null && method === 'GET') {
      let rows = db[collection];
      if (q.includeDeleted !== 'true') rows = rows.filter((x) => !x.deletedAt);

      // клиент видит только свои бронирования
      if (collection === 'bookings' && user && user.role === 'client') {
        rows = rows.filter((b) => b.clientId === user.clientId);
      }

      rows = applyFilters(collection, rows, q);
      rows = applySort(rows, q.sort);
      const page = paginate(rows, q);
      return send(res, 200, { ...page, items: page.items.map(expand) });
    }

    // одна запись
    if (id !== null && method === 'GET') {
      const row = db[collection].find(
        (x) => x.id === id && (q.includeDeleted === 'true' || !x.deletedAt),
      );
      if (!row) return fail(res, 404, 'Объект не найден');
      return send(res, 200, expand(row));
    }

    // создание
    if (id === null && method === 'POST') {
      if (!requireRole(res, user, 'manager')) return;
      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const errors = validate(collection, body);
      if (Object.keys(errors).length) {
        return send(res, 422, { message: 'Ошибка валидации', errors });
      }

      const newId = push(collection, normalize(collection, body));
      return send(res, 201, expand(db[collection].find((x) => x.id === newId)));
    }

    // изменение
    if (id !== null && (method === 'PUT' || method === 'PATCH')) {
      if (!requireRole(res, user, 'manager')) return;
      const row = db[collection].find((x) => x.id === id && !x.deletedAt);
      if (!row) return fail(res, 404, 'Объект не найден');

      const body = await readBody(req);
      if (!body) return fail(res, 400, 'Тело запроса не является корректным JSON');

      const merged = method === 'PATCH' ? { ...row, ...body } : body;
      const errors = validate(collection, merged, id);
      if (Object.keys(errors).length) {
        return send(res, 422, { message: 'Ошибка валидации', errors });
      }

      Object.assign(row, normalize(collection, merged));
      return send(res, 200, expand(row));
    }

    // удаление
    if (id !== null && method === 'DELETE') {
      const hard = q.hard === 'true';
      if (!requireRole(res, user, hard ? 'admin' : 'manager')) return;

      const index = db[collection].findIndex((x) => x.id === id);
      if (index === -1) return fail(res, 404, 'Объект не найден');

      if (hard) {
        if (collection === 'halls') {
          const active = db.bookings.some(
            (b) => b.hallId === id && b.status === 'active' && !b.deletedAt,
          );
          if (active) return fail(res, 409, 'В зале есть активные бронирования, удалить его нельзя');
        }
        if (collection === 'clients') {
          const active = db.bookings.some(
            (b) => b.clientId === id && b.status === 'active' && !b.deletedAt,
          );
          if (active) return fail(res, 409, 'У клиента есть активные бронирования');
        }
        db[collection].splice(index, 1);
      } else {
        db[collection][index].deletedAt = new Date().toISOString();
      }
      return send(res, 204);
    }
  }

  return fail(res, 404, `Адрес ${method} ${path} не обслуживается`);
}

function normalize(collection, body) {
  const num = (v) => (v == null || v === '' ? null : Number(v));
  const str = (v) => (v == null ? '' : String(v).trim());
  const ids = (v) =>
    Array.isArray(v) ? v.map(Number).filter((n) => Number.isInteger(n)) : [];

  switch (collection) {
    case 'halls':
      return {
        name: str(body.name),
        code: str(body.code).toUpperCase(),
        style: str(body.style),
        capacity: num(body.capacity),
        hourlyRate: num(body.hourlyRate),
        description: str(body.description),
      };
    case 'photographers':
      return {
        fullName: str(body.fullName),
        specialization: str(body.specialization),
        city: str(body.city),
        birthYear: num(body.birthYear),
        experienceYears: num(body.experienceYears),
        hourlyRate: num(body.hourlyRate),
      };
    case 'clients':
      return {
        fullName: str(body.fullName),
        email: str(body.email),
        phone: str(body.phone),
        clientType: str(body.clientType) || 'Частный',
        company: str(body.company),
        cardNumber: str(body.cardNumber).toUpperCase(),
        cardIssuedAt: str(body.cardIssuedAt),
        cardExpiresAt: str(body.cardExpiresAt),
      };
    case 'equipment':
      return {
        name: str(body.name),
        category: str(body.category),
        manufacturer: str(body.manufacturer),
        hallId: num(body.hallId),
        quantity: num(body.quantity),
        pricePerDay: num(body.pricePerDay),
      };
    case 'bookings':
      return {
        accessCode: str(body.accessCode).toUpperCase(),
        hallId: num(body.hallId),
        clientId: num(body.clientId),
        photographerIds: ids(body.photographerIds),
        date: body.date ? new Date(body.date).toISOString() : new Date().toISOString(),
        durationHours: num(body.durationHours),
        participants: num(body.participants),
        shootingType: str(body.shootingType),
        comment: str(body.comment),
        status: str(body.status) || 'active',
      };
    default:
      return { ...body };
  }
}

function expandUser(u) {
  return {
    id: u.id,
    username: u.username,
    fullName: u.fullName,
    email: u.email,
    role: u.role,
    clientId: u.clientId,
  };
}

// ─────────────────────────────── запуск ───────────────────────────────

seed();

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  // Предварительный запрос браузера. Без этого обработчика
  // на web не заработает ни один запрос с заголовком Authorization.
  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }

  // Учебная задержка: включается переменной окружения DEMO_DELAY_MS.
  const delay = Number(url.searchParams.get('__delay') || process.env.DEMO_DELAY_MS || 0);
  if (delay > 0) await new Promise((r) => setTimeout(r, Math.min(delay, 10000)));

  const started = Date.now();
  try {
    await handle(req, res, url);
  } catch (err) {
    console.error(err);
    if (!res.headersSent) fail(res, 500, 'Внутренняя ошибка сервера: ' + err.message);
  }
  console.log(
    `${req.method.padEnd(6)} ${url.pathname}${url.search}  → ${res.statusCode}  ${Date.now() - started} мс`,
  );
});

server.listen(PORT, () => {
  console.log('');
  console.log('  Учебное API «Фотостудия FocusFrame»');
  console.log(`  Адрес:              http://localhost:${PORT}/api`);
  console.log(`  Разрешённый источник: ${ORIGIN}`);
  console.log(`  Срок жизни токена:  ${ACCESS_TTL} с`);
  console.log('');
  console.log('  Учётные записи:  admin/admin123   manager/manager123');
  console.log('                   photographer/photographer123   client/client123');
  console.log('  Сброс данных:    POST /api/__reset');
  console.log('  Задержка ответа: любой запрос с ?__delay=1500');
  console.log('  Ошибка по требованию: любой запрос с ?__fail=500');
  console.log('');
});
