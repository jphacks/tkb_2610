import 'dotenv/config';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import { test, before, after } from 'node:test';
import { createApp } from '../dist/app.js';
import { supabase } from '../dist/lib/supabase.js';
import { getJstDayRange } from '../dist/utils/jst-day-range.js';

const actors = new Set();
const hooks = new Map();
const calls = new Map();
let server, base, config;
const range = getJstDayRange();
const dayMs = 86400000;
const day = (offset) => new Date(Date.parse(`${range.date}T00:00:00Z`) + offset * dayMs).toISOString().slice(0, 10);
const at = (offset, extra = 3600000) => new Date(Date.parse(range.startAt) + offset * dayMs + extra).toISOString();
const points = (overrides = {}) => ({ kindness: 0, environment: 0, gratitude: 0, courage: 0, cooperation: 0, honesty: 0, self_care: 0, ...overrides });
const judgement = (category = 'kindness') => ({ valid: true, category, praise: '具体的な行動で周りを助けられましたね。' });
async function fakeJudge(content) {
  calls.set(content, (calls.get(content) ?? 0) + 1);
  if (hooks.has(content)) return hooks.get(content)();
  if (content.startsWith('無効')) return { ...judgement(), valid: false };
  return judgement(content.includes('環境') ? 'environment' : content.includes('勇気') ? 'courage' : 'kindness');
}
async function db(query) {
  const result = await query.abortSignal(AbortSignal.timeout(15000));
  if (result.error) throw new Error(`DB ${result.error.code}: ${result.error.message}`);
  return result.data;
}
async function api(path, { actor, method = 'GET', body, raw } = {}) {
  const response = await fetch(`${base}${path}`, { method,
    headers: { ...(actor ? { Authorization: `Bearer ${actor.token}` } : {}), ...(body !== undefined || raw !== undefined ? { 'Content-Type': 'application/json' } : {}) },
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)), signal: AbortSignal.timeout(20000),
  });
  return { status: response.status, body: response.status === 204 ? null : await response.json() };
}
async function actor() {
  const result = await api('/api/guests', { method: 'POST', body: { displayName: '結合テスト専用' } });
  if (result.body?.user?.id) actors.add(result.body.user.id);
  assert.equal(result.status, 201);
  return { id: result.body.user.id, token: result.body.sessionToken, characterId: result.body.currentCharacter.id };
}
async function patch(a, values) { await db(supabase.from('characters').update(values).eq('id', a.characterId).eq('user_id', a.id)); }
async function post(a, content = `確認用の行動 ${randomUUID()}`, requestId = randomUUID()) {
  return api('/api/deeds', { actor: a, method: 'POST', body: { content, requestId } });
}
function deferred() { let resolve; const promise = new Promise((r) => { resolve = r; }); return { promise, resolve }; }
async function waitFor(promise) {
  let timer;
  try { await Promise.race([promise, new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('AI hook was not reached')), 10000); })]); }
  finally { clearTimeout(timer); }
}
before(async () => {
  config = await db(supabase.from('game_config').select('*').eq('singleton', true).single());
  server = createApp({ judgeDeed: fakeJudge }).listen(0, '127.0.0.1');
  await once(server, 'listening'); base = `http://127.0.0.1:${server.address().port}`;
});
after(async () => {
  try {
    if (actors.size) {
      await db(supabase.from('users').delete().in('id', [...actors]));
      for (const table of ['characters', 'deeds', 'deed_requests', 'guest_sessions', 'guest_registration_requests']) {
        const result = await supabase.from(table).select('*', { count: 'exact', head: true }).in('user_id', [...actors]).abortSignal(AbortSignal.timeout(15000));
        if (result.error) throw new Error(`Cleanup ${table}: ${result.error.code}`);
        assert.equal(result.count, 0, `Temporary data remains in ${table}`);
      }
      console.log(`Temporary users and related data cleaned: ${actors.size}`);
    }
  } finally { if (server) { server.closeAllConnections(); await new Promise((r) => server.close(r)); } }
});

test('稼働確認・カテゴリ・共通エラー・認証', async () => {
  assert.equal((await api('/api/health')).status, 200);
  const categories = await api('/api/categories');
  assert.equal(categories.body.categories.length, 7);
  assert.equal(categories.body.categories[6].id, 'self_care');
  for (const path of ['/api/users/me', '/api/characters/me', '/api/characters/history', '/api/characters/me/evolution', '/api/deeds', '/api/deeds/today']) {
    const result = await api(path); assert.equal(result.status, 401); assert.equal(result.body.error.code, 'UNAUTHENTICATED');
  }
  assert.equal((await api('/api/unknown')).body.error.code, 'NOT_FOUND');
  assert.equal((await api('/api/guests', { method: 'POST', raw: '{' })).status, 400);
  assert.equal((await api('/api/guests', { method: 'POST', body: { displayName: ' ' } })).status, 400);
  assert.equal((await api('/api/guests', { method: 'POST', raw: JSON.stringify({ displayName: 'a'.repeat(17000) }) })).status, 413);
});

test('ゲスト登録・プロフィール・名前変更・初期キャラクター・空の履歴', async () => {
  const a = await actor();
  let r = await api('/api/users/me', { actor: a });
  assert.equal(r.body.user.id, a.id); assert.equal(r.body.user.isGuest, true); assert.equal(r.body.user.longestSurvivalDays, 1);
  r = await api('/api/users/me', { actor: a, method: 'PUT', body: { displayName: '  新しい名前  ' } });
  assert.equal(r.body.user.displayName, '新しい名前');
  for (const body of [{ displayName: '' }, { displayName: 'あ'.repeat(21) }, { displayName: '名前\u0000' }, { displayName: 10 }, { displayName: '名前', userId: randomUUID() }]) {
    assert.equal((await api('/api/users/me', { actor: a, method: 'PUT', body })).status, 400);
  }
  r = await api('/api/characters/me', { actor: a });
  assert.equal(r.status, 200); assert.equal(r.body.currentCharacter.hp, 100);
  assert.equal(r.body.currentCharacter.deedCount, 0); assert.equal(r.body.currentCharacter.endReason, null);
  assert.equal(r.body.currentCharacter.categoryPoints.selfCare, 0);
  assert.equal(r.body.currentStreakDays, 0); assert.equal(r.body.canCreateNextCharacter, false);
  assert.equal(r.body.today.remainingXp, config.daily_xp_limit);
  assert.equal('secondEvolutionPoints' in r.body.currentCharacter, false);
  const history = await api('/api/characters/history', { actor: a });
  assert.equal(history.body.totalCount, 1); assert.equal(history.body.items[0].id, a.characterId);
  assert.deepEqual(Object.keys(history.body.items[0]).sort(), Object.keys(r.body.currentCharacter).sort());
  assert.equal((await api('/api/deeds', { actor: a })).body.totalCount, 0);
  assert.equal((await api('/api/deeds/today', { actor: a })).body.deedCount, 0);
  for (const path of ['/api/deeds?limit=0', '/api/deeds?offset=-1', '/api/deeds?limit=1.5', '/api/deeds?characterId=bad', '/api/characters/history?limit=51', '/api/characters/history?offset=2147483648']) {
    assert.equal((await api(path, { actor: a })).status, 400);
  }
  assert.equal((await api('/api/characters', { actor: a, method: 'POST' })).body.error.code, 'ACTIVE_CHARACTER_EXISTS');
});

test('善行保存・報酬・成功結果の再送・内容競合', async () => {
  const a = await actor(); await patch(a, { hp: 70 });
  const content = `環境のためごみを拾った ${randomUUID()}`, requestId = randomUUID();
  const r = await post(a, content, requestId);
  assert.equal(r.status, 201); assert.equal(r.body.deed.earnedXp, config.xp_per_deed);
  assert.equal(r.body.deed.earnedCategoryPoints, 1); assert.equal(r.body.deed.recoveredHp, Math.min(config.hp_recovery, 30));
  assert.equal(r.body.currentCharacter.deedCount, 1);
  const replay = await post(a, content, requestId);
  assert.deepEqual(replay, r); assert.equal(calls.get(content), 1);
  const conflict = await post(a, `${content}変更`, requestId);
  assert.equal(conflict.status, 409); assert.equal(conflict.body.error.code, 'IDEMPOTENCY_CONFLICT');
  const current = await api('/api/characters/me', { actor: a });
  assert.equal(current.body.today.deedCount, 1); assert.equal(current.body.currentStreakDays, 1);
  assert.equal(current.body.currentCharacter.totalXp, config.xp_per_deed);
});

test('善行ではない判定は同じ投稿IDで上書き・再判定できる', async () => {
  const a = await actor(), requestId = randomUUID(), invalid = `無効な入力 ${randomUUID()}`;
  assert.equal((await post(a, invalid, requestId)).status, 422);
  assert.equal((await post(a, invalid, requestId)).status, 422);
  assert.equal(calls.get(invalid), 2);
  let r = await api('/api/deeds/today', { actor: a }); assert.equal(r.body.deedCount, 0); assert.equal(r.body.earnedXp, 0);
  const corrected = `困っている人に道を教えた ${randomUUID()}`;
  r = await post(a, corrected, requestId); assert.equal(r.status, 201);
  assert.equal(r.body.deed.content, corrected); assert.equal(r.body.currentCharacter.deedCount, 1);
  assert.equal((await post(a, invalid, requestId)).status, 409);
  const saved = await db(supabase.from('deed_requests').select('content, http_status').eq('user_id', a.id).eq('request_id', requestId).single());
  assert.equal(saved.content, corrected); assert.equal(saved.http_status, 201);
});

test('同時投稿でもXP上限を超えず、上限後は属性ポイントも0', async () => {
  const a = await actor(); await patch(a, { hp: 70 });
  const n = Math.ceil(config.daily_xp_limit / config.xp_per_deed) + 3;
  const results = await Promise.all(Array.from({ length: n }, (_, i) => post(a, `同時投稿 ${i} ${randomUUID()}`)));
  for (const r of results) assert.equal(r.status, 201);
  assert.equal(results.reduce((sum, r) => sum + r.body.deed.earnedXp, 0), config.daily_xp_limit);
  const zeroRewards = results.filter((r) => r.body.deed.earnedXp === 0);
  assert.ok(zeroRewards.length > 0);
  assert.ok(zeroRewards.every((r) => r.body.deed.earnedCategoryPoints === 0));
  const current = (await api('/api/characters/me', { actor: a })).body;
  assert.equal(current.today.earnedXp, config.daily_xp_limit); assert.equal(current.today.remainingXp, 0);
  assert.equal(current.currentCharacter.deedCount, n); assert.equal(current.currentCharacter.hp, 100);
  assert.equal(current.currentCharacter.categoryPoints.kindness, Math.ceil(config.daily_xp_limit / config.xp_per_deed));
});

test('第1・第2進化、ポイント集計範囲、最終進化当日の投稿', async () => {
  const a = await actor();
  await patch(a, { total_xp: config.first_evolution_xp - config.xp_per_deed, category_points: points({ kindness: 5, environment: 5 }) });
  await db(supabase.from('deeds').insert([
    { category: 'kindness', stamp: new Date(Date.now() - 120000).toISOString() },
    { category: 'environment', stamp: new Date(Date.now() - 60000).toISOString() },
  ].map(({ category, stamp }) => ({ id: randomUUID(), user_id: a.id, character_id: a.characterId, request_id: randomUUID(),
    content: '進化判定用の一時データ', category, praise: '動作確認', earned_xp: 0, earned_category_points: 0, recovered_hp: 0, created_at: stamp }))));
  let r = await post(a, `勇気を出して助けた ${randomUUID()}`);
  assert.equal(r.status, 201); assert.equal(r.body.evolution.currentStage, 1);
  assert.equal(r.body.currentCharacter.firstEvolutionCategory, 'environment');
  assert.equal(r.body.currentCharacter.imageId, 'stage1_environment');
  let progress = (await api('/api/characters/me/evolution', { actor: a })).body;
  assert.equal(progress.nextEvolutionXp, config.second_evolution_xp);
  assert.equal(progress.categoryPoints.kindness, 0);
  await patch(a, { total_xp: config.second_evolution_xp - config.xp_per_deed, second_evolution_points: points({ kindness: 4, courage: 4 }) });
  r = await post(a, `勇気を出して協力した ${randomUUID()}`);
  assert.equal(r.status, 201); assert.equal(r.body.evolution.currentStage, 2);
  assert.equal(r.body.currentCharacter.secondEvolutionCategory, 'courage');
  assert.equal(r.body.currentCharacter.secondEvolutionDate, range.date);
  assert.equal(r.body.currentCharacter.imageId, 'stage2_environment_courage');
  progress = (await api('/api/characters/me/evolution', { actor: a })).body;
  assert.equal(progress.nextEvolutionXp, null); assert.equal(progress.remainingXp, null);
  r = await post(a); assert.equal(r.status, 201); assert.equal(r.body.currentCharacter.evolutionStage, 2);
  const current = (await api('/api/characters/me', { actor: a })).body;
  assert.equal(current.canCreateNextCharacter, false); assert.equal(current.currentCharacter.status, 'alive');
  assert.equal((await api('/api/characters', { actor: a, method: 'POST' })).status, 409);
});

test('未投稿ペナルティ・死亡確定・最長生存日数・同時世代交代', async () => {
  const a = await actor();
  await patch(a, { created_at: at(-8), hp: config.hp_loss_per_day * 2, last_penalty_applied_date: day(-8) });
  let current = (await api('/api/characters/me', { actor: a })).body;
  assert.equal(current.currentCharacter.hp, 0); assert.equal(current.currentCharacter.status, 'dead');
  assert.equal(current.currentCharacter.endReason, 'death'); assert.equal(current.currentCharacter.lifespanDays, 3);
  assert.equal(current.canCreateNextCharacter, true);
  assert.equal((await api('/api/users/me', { actor: a })).body.user.longestSurvivalDays, 3);
  assert.equal((await post(a)).body.error.code, 'CHARACTER_NOT_ACTIVE');
  const next = await Promise.all([api('/api/characters', { actor: a, method: 'POST' }), api('/api/characters', { actor: a, method: 'POST' })]);
  assert.deepEqual(next.map((r) => r.status).sort(), [201, 409]);
  const created = next.find((r) => r.status === 201).body.currentCharacter;
  assert.equal(created.generation, 2); assert.equal(created.hp, 100); assert.equal(created.totalXp, 0); assert.equal(created.deedCount, 0);
  const history = (await api('/api/characters/history', { actor: a })).body;
  assert.equal(history.totalCount, 2); assert.equal(history.items[0].generation, 2); assert.equal(history.items[1].status, 'dead');
  const again = (await api('/api/characters/me', { actor: a })).body;
  assert.equal(again.currentCharacter.id, created.id); assert.equal(again.currentCharacter.hp, 100);
});

test('第2進化の翌日はretiredになり、終了日以後はHPを減らさない', async () => {
  const a = await actor();
  await patch(a, { created_at: at(-4), hp: 80, evolution_stage: 2, first_evolution_category: 'kindness', second_evolution_category: 'environment',
    second_evolution_date: day(-1), last_penalty_applied_date: day(-1), total_xp: config.second_evolution_xp });
  const current = (await api('/api/characters/me', { actor: a })).body;
  assert.equal(current.currentCharacter.status, 'retired'); assert.equal(current.currentCharacter.endReason, 'second_evolution');
  assert.equal(current.currentCharacter.hp, 80); assert.equal(current.currentCharacter.lifespanDays, 4);
  assert.equal(Date.parse(current.currentCharacter.endedAt), Date.parse(range.startAt));
  assert.equal(current.canCreateNextCharacter, true);
  assert.equal((await api('/api/characters', { actor: a, method: 'POST' })).status, 201);
});

test('死亡当日の次世代作成は拒否される', async () => {
  const a = await actor();
  await patch(a, { hp: 0, status: 'dead', died_at: new Date().toISOString(), ended_at: new Date().toISOString(), end_reason: 'death' });
  const current = (await api('/api/characters/me', { actor: a })).body;
  assert.equal(current.canCreateNextCharacter, false);
  const result = await api('/api/characters', { actor: a, method: 'POST' });
  assert.equal(result.status, 409); assert.equal(result.body.error.code, 'GENERATION_NOT_AVAILABLE');
});

test('善行履歴のページ分割・キャラクター絞り込み・他ユーザーの拒否', async () => {
  const a = await actor(), b = await actor();
  await post(a); await post(a); await post(b);
  const first = (await api('/api/deeds?limit=1&offset=0', { actor: a })).body;
  const second = (await api('/api/deeds?limit=1&offset=1', { actor: a })).body;
  assert.equal(first.totalCount, 2); assert.equal(first.hasMore, true); assert.equal(second.hasMore, false);
  assert.notEqual(first.items[0].id, second.items[0].id);
  assert.equal((await api(`/api/deeds?characterId=${a.characterId}`, { actor: a })).body.totalCount, 2);
  assert.equal((await api(`/api/deeds?characterId=${b.characterId}`, { actor: a })).status, 404);
  assert.equal((await api(`/api/deeds?characterId=${randomUUID()}`, { actor: a })).status, 404);
});

test('同じ投稿の処理中リクエストは409、終了後は保存結果を返す', async () => {
  const a = await actor(), requestId = randomUUID(), content = `待機 ${randomUUID()}`;
  const started = deferred(), release = deferred();
  hooks.set(content, async () => { started.resolve(); await release.promise; return judgement(); });
  const pending = post(a, content, requestId);
  try {
    await waitFor(started.promise);
    const duplicate = await post(a, content, requestId);
    assert.equal(duplicate.body.error.code, 'REQUEST_IN_PROGRESS');
  } finally { release.resolve(); }
  const first = await pending; assert.equal(first.status, 201);
  assert.deepEqual(await post(a, content, requestId), first); assert.equal(calls.get(content), 1);
});

test('AI障害は保存・付与せず、同じ投稿IDで再試行できる', async () => {
  const a = await actor(), content = `障害回復 ${randomUUID()}`, id = randomUUID(); let fail = true;
  hooks.set(content, async () => { if (fail) throw new Error('Synthetic upstream failure'); return judgement(); });
  assert.equal((await post(a, content, id)).status, 503);
  let r = (await api('/api/deeds/today', { actor: a })).body; assert.equal(r.deedCount, 0); assert.equal(r.earnedXp, 0);
  fail = false; assert.equal((await post(a, content, id)).status, 201);
  r = (await api('/api/deeds/today', { actor: a })).body; assert.equal(r.deedCount, 1);
});

test('期限切れリースの旧処理は報酬を確定できない', async () => {
  const a = await actor(), requestId = randomUUID(), lease1 = randomUUID(), lease2 = randomUUID();
  const args = { p_user_id: a.id, p_request_id: requestId, p_content: 'リース確認用', p_lease_token: lease1 };
  await db(supabase.rpc('begin_deed_request', args));
  await db(supabase.from('deed_requests').update({ lease_until: new Date(Date.now() - 1000).toISOString() }).eq('user_id', a.id).eq('request_id', requestId));
  await db(supabase.rpc('begin_deed_request', { ...args, p_lease_token: lease2 }));
  const finish = { p_user_id: a.id, p_request_id: requestId, p_lease_token: lease1, p_valid: true, p_category: 'kindness', p_praise: '動作確認' };
  assert.equal((await db(supabase.rpc('finish_deed_request', finish))).errorCode, 'REQUEST_IN_PROGRESS');
  assert.equal((await db(supabase.rpc('finish_deed_request', { ...finish, p_lease_token: lease2 }))).httpStatus, 201);
  assert.equal((await api('/api/deeds/today', { actor: a })).body.deedCount, 1);
});

test('AI判定中の世代交代では、元の投稿を新世代へ付け替えない', async () => {
  const a = await actor(), content = `世代競合 ${randomUUID()}`;
  const started = deferred(), release = deferred();
  hooks.set(content, async () => { started.resolve(); await release.promise; return judgement(); });
  const pending = post(a, content);
  try {
    await waitFor(started.promise);
    await patch(a, { created_at: at(-3), hp: 0, status: 'dead', died_at: at(-1), ended_at: at(-1), end_reason: 'death' });
    assert.equal((await api('/api/characters', { actor: a, method: 'POST' })).status, 201);
  } finally { release.resolve(); }
  const result = await pending;
  assert.equal(result.status, 409); assert.equal(result.body.error.code, 'CHARACTER_NOT_ACTIVE');
  assert.equal((await api('/api/deeds/today', { actor: a })).body.deedCount, 0);
});

test('退会は全関連データを削除し、トークンを無効にする', async () => {
  const a = await actor(); await post(a);
  const result = await api('/api/users/me', { actor: a, method: 'DELETE' }); assert.equal(result.status, 204);
  assert.equal((await api('/api/users/me', { actor: a })).status, 401);
  const rows = await db(supabase.from('deed_requests').select('request_id').eq('user_id', a.id)); assert.equal(rows.length, 0);
});

test('AI判定中に退会しても、投稿やユーザーが復活しない', async () => {
  const a = await actor(), content = `退会競合 ${randomUUID()}`;
  const started = deferred(), release = deferred();
  hooks.set(content, async () => { started.resolve(); await release.promise; return judgement(); });
  const pending = post(a, content);
  try {
    await waitFor(started.promise);
    assert.equal((await api('/api/users/me', { actor: a, method: 'DELETE' })).status, 204);
  } finally { release.resolve(); }
  const result = await pending; assert.equal(result.status, 404); assert.equal(result.body.error.code, 'USER_NOT_FOUND');
  assert.equal((await db(supabase.from('users').select('id').eq('id', a.id))).length, 0);
});
