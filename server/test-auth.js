'use strict';
const {spawn} = require('node:child_process');
const {once} = require('node:events');
const assert = require('node:assert/strict');
const path = require('node:path');
const ttl = Number(process.argv[2] || 1);
const maxSession = ttl >= 60 ? 1800 : 4;
const server = spawn(process.execPath, [path.join(__dirname, 'mock-server.js'), '--port', '18082', '--ttl', String(ttl), '--session-ttl', String(maxSession), '--ephemeral'],
  {stdio:['ignore','pipe','pipe'], windowsHide:true});
let checks = 0;
function check(value, message) { assert.ok(value, message); checks++; }
async function req(resource, method='GET', data, token, extraHeaders={}) {
  const r = await fetch('http://localhost:18082/api'+resource, {method,
    headers:{'Content-Type':'application/json', ...(token ? {Authorization:'Bearer '+token}: {}), ...extraHeaders},
    body:data === undefined ? undefined : JSON.stringify(data)});
  const text = await r.text(); return {status:r.status, data:text ? JSON.parse(text) : null};
}
async function login(username,password) { return (await req('/auth/login','POST',{username,password})).data; }
async function main() {
  await Promise.race([once(server.stdout,'data'),once(server,'exit').then(()=>{throw Error('Server startup failed');})]);
  check((await req('/auth/login','POST',{username:'client',password:'wrong'})).status===401,'invalid login');
  for (const resource of ['/halls','/bookings','/clients','/equipment','/photographers','/halls/1','/account/bookings','/manager/workspace','/users','/admin/statistics']) {
    check((await req(resource)).status===401,'anonymous denied '+resource);
  }
  for (const password of ['abc','abcdefgh!','abcdefgh1']) {
    const r = await req('/auth/register','POST',{username:'newclient',fullName:'Новый Клиент',email:'newclient@example.com',password});
    check(r.status===422 && r.data.errors.password,'password rule '+password);
  }
  const input = {username:'newclient', fullName:'Новый Клиент', email:'newclient@example.com', password:'Photo123!', role:'admin'};
  const registration = await req('/auth/register','POST',input);
  check(registration.status===201 && registration.data.role==='client','registration cannot assign admin');
  const duplicate = await req('/auth/register','POST',input);
  check(duplicate.status===422 && duplicate.data.errors.username,'duplicate login');
  const created = await login(input.username,input.password);
  check(created.user.role==='client' && created.user.clientId,'registration creates linked studio client');
  check((await req('/account/bookings','GET',undefined,created.accessToken)).data.length===0,'new client starts with own empty bookings');
  const client = await login('client','client123');
  const manager = await login('manager','manager123');
  const admin = await login('admin','admin123');
  const c=client.accessToken, m=manager.accessToken, a=admin.accessToken;
  check((await req('/auth/me','GET',undefined,c)).data.role==='client','profile from signed token');
  check((await req('/account/bookings','GET',undefined,c)).status===200,'client exclusive screen');
  check((await req('/account/bookings','GET',undefined,m)).status===403,'manager denied client workspace');
  check((await req('/account/bookings','GET',undefined,a)).status===403,'admin denied client workspace');
  check((await req('/manager/workspace','GET',undefined,m)).status===200,'manager exclusive screen');
  check((await req('/manager/workspace','GET',undefined,c)).status===403,'client denied manager workspace');
  check((await req('/manager/workspace','GET',undefined,a)).status===403,'admin denied manager workspace');
  check((await req('/users','GET',undefined,a)).status===200,'admin users');
  check((await req('/admin/statistics','GET',undefined,a)).status===200,'admin statistics');
  check((await req('/admin/statistics','GET',undefined,m)).status===403,'manager denied stats');
  check((await req('/users','GET',undefined,c,{'X-UI-Role':'admin'})).status===403,'forged UI role cannot read users');
  check((await req('/halls/1','DELETE',undefined,c,{'X-UI-Role':'admin'})).status===403,'forged UI role cannot delete hall');
  check((await req('/halls/1?hard=true','DELETE',undefined,m)).status===403,'manager cannot purge');
  const own = (await req('/account/bookings','GET',undefined,c)).data;
  check(own.every(b=>b.client.id===client.user.clientId),'only own bookings');
  const all = (await req('/bookings?size=100','GET',undefined,a)).data.items;
  const foreign = all.find(b=>b.client.id!==client.user.clientId);
  check((await req('/bookings/'+foreign.id,'GET',undefined,c)).status===403,'cannot read another client booking by id');
  check((await req('/bookings/'+foreign.id+'/extend','POST',{},c)).status===403,'cannot extend another client booking');
  const b = own.find(b=>b.status==='active');
  const extended = await req('/bookings/'+b.id+'/extend','POST',{},c);
  check(extended.status===200 && extended.data.durationHours===b.durationHours+1,'client can extend own booking');
  check((await req('/users/'+created.user.id+'/role','PATCH',{role:'admin'},m)).status===403,'manager cannot assign role');
  check((await req('/users/'+created.user.id+'/role','PATCH',{role:'manager'},a)).status===200,'admin can assign role');
  check((await req('/manager/workspace','GET',undefined,created.accessToken)).status===200,'server uses actual user role after role change');
  check((await req('/users/'+admin.user.id+'/role','PATCH',{role:'client'},a)).status===409,'admin cannot demote self');
  const revoked = await login('client','client123');
  await req('/auth/logout','POST',{refreshToken:revoked.refreshToken});
  check((await req('/auth/me','GET',undefined,revoked.accessToken)).status===401,'logout revokes session access');
  check((await req('/auth/refresh','POST',{refreshToken:revoked.refreshToken})).status===401,'logout revokes refresh');
  const expiring = await login('client','client123');
  console.log(`Checking real access expiry (--ttl ${ttl}); waiting ${ttl+1} seconds`);
  await new Promise(resolve=>setTimeout(resolve,(ttl+1)*1000));
  check((await req('/auth/me','GET',undefined,expiring.accessToken)).status===401,'access expired');
  const refreshed = await req('/auth/refresh','POST',{refreshToken:expiring.refreshToken});
  check(refreshed.status===200 && refreshed.data.accessToken!==expiring.accessToken,'refresh rotates tokens');
  check((await req('/auth/me','GET',undefined,refreshed.data.accessToken)).status===200,'new access works');
  check((await req('/auth/refresh','POST',{refreshToken:expiring.refreshToken})).status===401,'old refresh cannot be reused');
  if (ttl<60) {
    await new Promise(resolve=>setTimeout(resolve,3100));
    check((await req('/auth/refresh','POST',{refreshToken:refreshed.data.refreshToken})).status===401,'absolute lifetime cannot be extended by refresh');
  }
  console.log(`PR5 auth: ${checks} checks passed`);
}
main().catch(e=>{console.error(e);process.exitCode=1;}).finally(()=>server.kill());
