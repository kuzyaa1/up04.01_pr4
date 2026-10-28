'use strict';
// Isolated API regression suite. Never changes an already running user server.
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const assert = require('node:assert/strict');
const path = require('node:path');
const server = spawn(process.execPath, [path.join(__dirname, 'mock-server.js'), '--port', '18081', '--ephemeral'], { stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
let checks = 0;
let defaultToken;
function check(value, message) { assert.ok(value, message); checks++; }
async function req(resource, method = 'GET', data, token = defaultToken) {
  const response = await fetch('http://localhost:18081/api' + resource, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: data === undefined ? undefined : JSON.stringify(data),
  });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null, headers: response.headers };
}
async function main() {
  await Promise.race([once(server.stdout, 'data'), once(server, 'exit').then(() => { throw Error('Server failed to start'); })]);
  const login = await req('/auth/login', 'POST', { username: 'admin', password: 'admin123' });
  check(login.status === 200, 'admin login');
  const token = login.data.accessToken;
  defaultToken = token;
  const fixtures = require('./seed-pr3.json');
  for (const collection of Object.keys(fixtures)) {
    const result = await req('/' + collection + '?size=100');
    check(result.data.total === fixtures[collection].length, collection + ' retains PR3 data');
  }
  const hall = { name: 'Проверочный зал', code: 'AUDIT-01', style: 'Лофт', capacity: 10, hourlyRate: 1500 };
  const client = { fullName: 'Тестовый Клиент', email: 'audit@example.com', phone: '+79009999991', clientType: 'Частный', notes: 'Заметка из ПР3' };
  const person = { fullName: 'Тестовый Фотограф', specialization: 'Портрет', experienceYears: 3, hourlyRate: 2000, city: 'Описание из ПР3', hallIds: [] };
  async function crud(collection, body, field, value) {
    check((await req('/' + collection, 'POST', body, null)).status === 401, collection + ' needs token');
    const created = await req('/' + collection, 'POST', body, token);
    check(created.status === 201, collection + ' create: ' + JSON.stringify(created.data));
    const id = created.data.id;
    check((await req(`/${collection}/${id}`)).status === 200, collection + ' read');
    const changed = await req(`/${collection}/${id}`, 'PUT', { ...body, [field]: value }, token);
    check(changed.status === 200, collection + ' update');
    check(changed.data[field] === value, collection + ' update persisted');
    check((await req(`/${collection}/${id}`, 'DELETE', undefined, token)).status === 204, collection + ' soft delete');
    check((await req(`/${collection}/${id}`)).status === 404, collection + ' deleted hidden');
    check((await req(`/${collection}/${id}/restore`, 'POST', undefined, token)).status === 200, collection + ' restore');
    check((await req(`/${collection}/bulk-delete`, 'POST', { ids: [id] }, token)).data.deleted === 1, collection + ' bulk delete');
    check((await req(`/${collection}/${id}`, 'DELETE', undefined, token)).status === 204, collection + ' hard fixture cleanup soft idempotent');
    check((await req(`/${collection}/${id}?hard=true`, 'DELETE', undefined, token)).status === 204, collection + ' hard delete');
  }
  await crud('halls', hall, 'capacity', 11);
  await crud('clients', client, 'notes', 'Изменённая заметка');
  await crud('photographers', person, 'city', 'Изменённое описание');
  const h = (await req('/halls', 'POST', hall, token)).data;
  person.hallIds = [h.id];
  const p = (await req('/photographers', 'POST', person, token)).data;
  const c = (await req('/clients', 'POST', client, token)).data;
  check(p.hallIds.includes(h.id), 'photographer hall links persist');
  await crud('equipment', { name: 'Тестовый свет', category: 'Свет', manufacturer: 'Test', hallId: h.id, quantity: 2, pricePerDay: 100 }, 'quantity', 3);
  const booking = { accessCode: 'AUDIT-BOOK', email: 'contact@example.com', hallId: h.id, clientId: c.id, photographerIds: [p.id], date: '2030-07-02T00:00:00.000Z', durationHours: 2, participants: 2, shootingType: 'Портрет', comment: 'ПР3 + ПР4' };
  await crud('bookings', booking, 'participants', 3);
  const b = await req('/bookings', 'POST', booking, token);
  check(b.status === 201 && b.data.email === booking.email, 'booking contact email persists');
  check((await req('/bookings', 'POST', { ...booking, date: '2030-07-03' }, token)).data.errors.accessCode, 'POST duplicate booking 422');
  check((await req('/bookings', 'POST', { ...booking, accessCode: 'AUDIT-OTHER' }, token)).status === 409, 'occupied hall 409');
  for (const [field, value] of [['date', '2030-02-30'], ['hallId', 999999], ['clientId', 999999], ['photographerIds', [999999]], ['durationHours', 0], ['participants', 100]]) {
    const response = await req('/bookings', 'POST', { ...booking, accessCode: 'INVALID-TEST', [field]: value }, token);
    check(response.status === 422 && response.data.errors[field], field + ' validation 422');
  }
  const other = await req('/bookings', 'POST', { ...booking, accessCode: 'AUDIT-SECOND', date: '2030-07-04' }, token);
  check(other.status === 201, 'another date allowed');
  check((await req('/bookings/' + other.data.id, 'PUT', { ...booking, accessCode: 'AUDIT-SECOND' }, token)).status === 409, 'update checks collision');
  for (const [collection, id] of [['halls', h.id], ['clients', c.id], ['photographers', p.id]]) {
    check((await req(`/${collection}/${id}`, 'DELETE', undefined, token)).status === 409, collection + ' links protect soft delete');
    check((await req(`/${collection}/${id}?hard=true`, 'DELETE', undefined, token)).status === 409, collection + ' links protect hard delete');
    check((await req(`/${collection}/bulk-delete`, 'POST', { ids: [id] }, token)).status === 409, collection + ' links protect bulk');
  }
  check((await req('/bookings/' + b.data.id, 'DELETE', undefined, token)).status === 204, 'soft delete booking');
  check((await req('/bookings', 'POST', { ...booking, accessCode: 'AUDIT-REPLACE' }, token)).status === 201, 'deleted booking frees day');
  check((await req(`/bookings/${b.data.id}/restore`, 'POST', undefined, token)).status === 409, 'restore checks conflict');
  const first = await req('/halls?page=1&size=2&sort=name,asc');
  const second = await req('/halls?page=2&size=2&sort=name,asc');
  check(first.data.items.length === 2 && second.data.items.length === 2 && first.data.items[0].id !== second.data.items[0].id, 'server pagination');
  check((await req('/photographers?hallId=' + h.id)).data.items.every(row => row.hallIds.includes(h.id)), 'server hall filter');
  const options = await req('/halls', 'OPTIONS');
  check(options.status === 204 && options.headers.get('access-control-allow-origin') === 'http://localhost:5555', 'CORS preflight');
  check((await req('/halls?__fail=500')).status === 500, 'forced server failure');
  const started = Date.now();
  check((await req('/halls?__delay=1500')).status === 200 && Date.now() - started >= 1450, 'delay switch');
  console.log(`API: ${checks} checks passed`);
}
main().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => server.kill());
