// Testes da Edge Function ia-consultor com provedores FALSOS (sem chave real, sem rede).
// Uso: node test_edge.mjs   (depois de gerar ia_check.mjs com esbuild)
import assert from 'node:assert/strict';

let handler;
const envs = { GEMINI_API_KEY: 'g', GROQ_API_KEY: 'q1', GROQ_API_KEY_2: 'q2' };
globalThis.Deno = { serve: (h) => { handler = h; }, env: { get: (k) => envs[k] } };

// Roteiro do fetch: para cada provedor, uma fila de respostas.
let roteiro = {};
const chamadas = [];
globalThis.fetch = async (url, init) => {
  const nome = url.includes('generativelanguage') ? 'gemini' : url.includes('groq') ? 'groq' : 'outro';
  chamadas.push(nome);
  const fila = roteiro[nome] ?? [];
  const r = fila.length > 1 ? fila.shift() : fila[0];
  if (!r) return new Response(JSON.stringify({ error: { code: 'x' } }), { status: 500 });
  if (r.status !== 200) return new Response(JSON.stringify({ error: { code: r.codigo ?? 'erro' } }), { status: r.status });
  const texto = JSON.stringify(r.corpo);
  const body = nome === 'gemini'
    ? { candidates: [{ content: { parts: [{ text: texto }] } }] }
    : { choices: [{ message: { content: texto } }] };
  return new Response(JSON.stringify(body), { status: 200 });
};

await import('./ia_check.mjs');
// Token com "sub" (a função lê o usuário do JWT para o limite por minuto).
const jwt = ['e30', btoa(JSON.stringify({ sub: 'teste-' + Math.random() })).replace(/=+$/, ''), 'x'].join('.');
const pedir = async (corpo, extra = {}) => {
  const r = await handler(new Request('http://x/ia', {
    method: 'POST', headers: { authorization: `Bearer ${jwt}`, 'content-type': 'application/json', ...extra },
    body: typeof corpo === 'string' ? corpo : JSON.stringify(corpo),
  }));
  return { status: r.status, corpo: await r.json() };
};
const base = { pergunta: 'O que repor?', snapshotVersion: 's1', atualizadoEm: '2026-10-15T12:00:00Z',
  metricas: { curvaAbc: { valorLiquidoTotalCentavos: 501600 } } };
const ok = (resposta, tipo = 'analise') => ({ status: 200, corpo: { resposta, tipo, metricas: {}, fontes: [] } });
let falhas = 0;
const caso = async (nome, f) => {
  try { await f(); console.log('ok  ', nome); } catch (e) { falhas++; console.log('FALHA', nome, '\n     ', e.message); }
};

await caso('entrada null vira 400', async () => {
  assert.equal((await pedir('null')).status, 400);
});
await caso('JSON {} do Gemini não para a cadeia: Groq responde', async () => {
  roteiro = { gemini: [{ status: 200, corpo: {} }], groq: [ok('Reponha o café.')] };
  const r = await pedir(base);
  assert.equal(r.status, 200);
  assert.equal(r.corpo.provedor, 'groq');
});
await caso('resposta só com espaços/campo vazado não é aceita', async () => {
  roteiro = { gemini: [ok('   ')], groq: [ok('Reponha o Leite.')] };
  const r = await pedir(base);
  assert.equal(r.corpo.provedor, 'groq');
});
await caso('tipo inválido passa para o próximo provedor', async () => {
  roteiro = { gemini: [{ status: 200, corpo: { resposta: 'x', tipo: 'qualquer' } }], groq: [ok('Ok, reponha.')] };
  assert.equal((await pedir(base)).corpo.provedor, 'groq');
});
await caso('dinheiro chega ao modelo em R$, nunca em centavos', async () => {
  let enviado = '';
  const f = globalThis.fetch;
  globalThis.fetch = async (url, init) => { if (url.includes('groq')) enviado = init.body; return f(url, init); };
  roteiro = { gemini: [{ status: 503 }], groq: [ok('Faturou R$ 5.016,00.')] };
  await pedir(base);
  globalThis.fetch = f;
  assert.match(enviado, /R\$ 5\.016,00/);
  assert.doesNotMatch(enviado, /501600/);
});
await caso('primeira letra maiúscula e nome de campo removido', async () => {
  roteiro = { gemini: [ok('arroz (estoqueDisponivel 30) está ok. produtoId 7894.')] };
  const r = await pedir(base);
  assert.match(r.corpo.resposta, /^Arroz/);
  assert.doesNotMatch(r.corpo.resposta, /estoqueDisponivel|produtoId/);
});
await caso('429 no Gemini: disjuntor pula o Gemini na pergunta seguinte', async () => {
  roteiro = { gemini: [{ status: 429, codigo: 'RESOURCE_EXHAUSTED' }], groq: [ok('Primeira.'), ok('Segunda.')] };
  await pedir(base);
  chamadas.length = 0;
  const r = await pedir(base);
  assert.equal(r.corpo.provedor, 'groq');
  assert.ok(!chamadas.includes('gemini'), 'Gemini não devia ser chamado: ' + chamadas.join(','));
});
await caso('todas as IAs em 429: responde 429 (o app mostra os números calculados)', async () => {
  roteiro = { gemini: [{ status: 429 }], groq: [{ status: 429, codigo: 'rate_limit_exceeded' }] };
  const r = await pedir({ ...base, pergunta: 'outra' });
  assert.ok([429, 503].includes(r.status), 'status ' + r.status);
});
console.log(falhas ? `\n${falhas} falha(s)` : '\nTodos os testes da Edge passaram.');
process.exit(falhas ? 1 : 0);
