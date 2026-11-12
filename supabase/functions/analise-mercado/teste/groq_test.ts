import { strict as assert } from 'node:assert';
import search from './fixtures/groq_search_results.json' with { type: 'json' };
import browser from './fixtures/groq_browser_output.json' with { type: 'json' };
import { buscarOfertas, ofertasGroq, provedores } from '../busca.ts';

const agora = '2026-10-17T15:00:00.000Z';
const json = (valor: unknown) => Promise.resolve(Response.json(valor));

Deno.test('Groq search_results: preço do resultado, hostname, HTTPS, dedupe; nunca texto final', () => {
  assert.deepEqual(ofertasGroq(search, agora), [
    { preco: 22.9, fonte: 'mercado-a.example', url: 'https://mercado-a.example/arroz', coletadaEm: agora },
    { preco: 23.5, fonte: 'mercado-b.example', url: 'https://mercado-b.example/arroz', coletadaEm: agora },
  ]);
});

Deno.test('Groq output/browser_results: url e text do registro, sem preço inventado', () => {
  assert.deepEqual(ofertasGroq(browser, agora).map((o) => [o.preco, o.fonte]), [
    [7.9, 'hortifruti.example'], [8.5, 'mercado.example'],
  ]);
});

Deno.test('Groq output JSON serializado, array ou registro único; prosa não é resultado', () => {
  const resultado = { url: 'https://loja.example/produto', text: 'R$ 12,90' };
  for (const output of [resultado, [resultado], { browser_results: { results: [resultado] } }, JSON.stringify({ results: [resultado] })]) {
    assert.equal(ofertasGroq({ choices: [{ message: { executed_tools: [{ type: 'browser_search', output }] } }] }, agora)[0].preco, 12.9);
  }
  assert.deepEqual(ofertasGroq({ choices: [{ message: { content: 'R$ 0,01 https://loja.example/',
    executed_tools: [{ output: 'R$ 0,01 https://loja.example/' }] } }] }, agora), []);
});

Deno.test('Groq falha fechada: payload incompleto, ferramenta errada e outros choices ignorados', () => {
  for (const dado of [null, {}, { choices: [] }, { choices: [{ message: { content: 'R$ 1,00' } }] },
    { choices: [{}, ...search.choices] },
    { choices: [{ message: { executed_tools: [{ type: 'code_interpreter', output: [{ url: 'https://loja.example/', text: 'R$ 1,00' }] }] } }] }]) {
    assert.deepEqual(ofertasGroq(dado, agora), []);
  }
});

Deno.test('Groq até oito ofertas; preço zero/fora do limite e unidades ambíguas descartados', () => {
  const results = Array.from({ length: 12 }, (_, i) => ({ url: `https://loja-${i}.example/`, text: 'R$ 12,90' }));
  const estrutura = (itens: unknown[]) => ({ choices: [{ message: { executed_tools: [{ output: itens }] } }] });
  assert.equal(ofertasGroq(estrutura(results), agora).length, 8);
  assert.deepEqual(ofertasGroq(estrutura(['R$ 0,00', 'R$ 100000,00', 'De R$ 20,00 por R$ 10,00'].map((text) => ({ url: 'https://loja.example/', text }))), agora), []);
});

Deno.test('ordem groq → gemini → brave; reserva sozinha também configura Groq', () => {
  assert.deepEqual(provedores({ groqKey: 'a', groqKey2: 'b', geminiKey: 'g', braveKey: 'c' }), ['groq', 'gemini', 'brave']);
  assert.deepEqual(provedores({ groqKey2: 'b' }), ['groq']);
  assert.deepEqual(provedores({ groqKey: ' ' }), []);
});

Deno.test('Groq primário usa browser_search obrigatório e GPT OSS 120b; não chama reservas após sucesso', async () => {
  let chamadas = 0;
  const r = await buscarOfertas('Arroz', '789', { groqKey: 'chave-teste', groqKey2: 'reserva', geminiKey: 'g', braveKey: 'b' }, (url, init) => {
    chamadas++;
    assert.equal(String(url), 'https://api.groq.com/openai/v1/chat/completions');
    assert.equal(new Headers(init?.headers).get('Authorization'), 'Bearer chave-teste');
    const corpo = JSON.parse(String(init?.body));
    assert.equal(corpo.model, 'openai/gpt-oss-120b');
    assert.deepEqual(corpo.tools, [{ type: 'browser_search' }]);
    assert.equal(corpo.tool_choice, 'required');
    assert.equal(JSON.parse(corpo.messages[1].content).codigoDeBarras, '789');
    assert.ok(!String(init?.body).includes('chave-teste'));
    return json(search);
  }, agora);
  assert.equal(chamadas, 1);
  assert.equal(r.ofertas.length, 2);
});

Deno.test('Groq usa segunda chave antes de cair para GPT OSS 20b e deduplica chaves iguais', async () => {
  const chamadas: string[] = [];
  const r = await buscarOfertas('Arroz', '', { groqKey: 'principal', groqKey2: 'reserva' }, (_url, init) => {
    chamadas.push(new Headers(init?.headers).get('Authorization')!);
    return chamadas.length === 1 ? Promise.resolve(new Response('', { status: 429 })) : json(search);
  }, agora);
  assert.deepEqual(chamadas, ['Bearer principal', 'Bearer reserva']);
  assert.equal(r.ofertas.length, 2);
  const modelos: string[] = [];
  await buscarOfertas('Arroz', '', { groqKey: 'mesma', groqKey2: 'mesma' }, (_url, init) => {
    modelos.push(JSON.parse(String(init?.body)).model);
    return modelos.length === 1 ? Promise.resolve(new Response('', { status: 404 })) : json(browser);
  }, agora);
  assert.deepEqual(modelos, ['openai/gpt-oss-120b', 'openai/gpt-oss-20b']);
});

for (const caso of ['rede', 'json', 'sem_resultados', 'formato', 'cota']) {
  Deno.test(`Groq → cadeia Gemini → Brave após ${caso}`, async () => {
    const chamadas: string[] = [];
    const r = await buscarOfertas('Arroz', '', { groqKey: 'p', groqKey2: 'r', geminiKey: 'g', braveKey: 'b' }, (url, init) => {
      const u = String(url);
      chamadas.push(u.includes('api.groq.com') ? JSON.parse(String(init?.body)).model : u.includes('generativelanguage') ? 'gemini' : 'brave');
      if (u.includes('api.search.brave.com')) return json({ web: { results: [{ title: 'R$ 12,90', url: 'https://loja.example/' }] } });
      if (u.includes('generativelanguage')) return Promise.resolve(Response.json({ error: { status: 'RESOURCE_EXHAUSTED' } }, { status: 429 }));
      if (caso === 'rede') return Promise.reject(new Error('segredo-que-nao-deve-sair'));
      if (caso === 'json') return Promise.resolve(new Response('não JSON'));
      if (caso === 'sem_resultados') return json({ choices: [{ message: { content: 'R$ 0,01' } }] });
      if (caso === 'formato') return json({ outro: {} });
      return Promise.resolve(new Response('', { status: 429 }));
    }, agora);
    assert.deepEqual(chamadas, ['openai/gpt-oss-120b', 'openai/gpt-oss-120b', 'openai/gpt-oss-20b', 'openai/gpt-oss-20b', 'gemini', 'gemini', 'gemini', 'gemini', 'brave']);
    assert.equal(r.ofertas[0].preco, 12.9);
  });
}

Deno.test('diagnóstico mostra apenas provedor/modelo, HTTP e status permitido', async () => {
  let i = 0;
  const r = await buscarOfertas('Arroz privado', '', { groqKey: 'segredo-chave' }, () => {
    i++;
    return Promise.resolve(Response.json({ error: { code: i === 1 ? 'rate_limit_exceeded' : 'segredo-chave', message: 'Arroz privado segredo-chave' } }, { status: 429 }));
  }, agora);
  assert.deepEqual(r.diagnostico, ['groq/openai/gpt-oss-120b:429:rate_limit_exceeded', 'groq/openai/gpt-oss-20b:429']);
  assert.ok(!JSON.stringify(r).includes('segredo-chave'));
  assert.ok(!JSON.stringify(r).includes('Arroz privado'));
});

Deno.test('resposta 200 sem resultados estruturados não finge busca validada', async () => {
  const r = await buscarOfertas('Arroz privado', '', { groqKey2: 'segredo-chave' }, () =>
    json({ choices: [{ message: { content: 'Preço inventado R$ 0,01 https://inventada.example/' } }] }), agora);
  assert.deepEqual(r.ofertas, []);
  assert.equal(r.diagnostico?.length, 2);
  assert.ok(r.diagnostico?.[0].startsWith('groq/openai/gpt-oss-120b:200:sem_ofertas_verificaveis:tools=0:nenhuma'));
  assert.ok(r.diagnostico?.[1].startsWith('groq/openai/gpt-oss-20b:200:sem_ofertas_verificaveis:'));
  // o raio-X mostra só estrutura: nada do texto gerado, nem preço, nem URL
  assert.ok(!JSON.stringify(r.diagnostico).includes('inventad'));
  assert.ok(!JSON.stringify(r.diagnostico).includes('0,01'));
  assert.ok(!JSON.stringify(r).includes('segredo-chave'));
});

Deno.test('formato real do Groq (17/10/2026): browser.search / browser.open com search_results', () => {
  const dados = { choices: [{ message: { role: 'assistant', content: 'Texto gerado com R$ 1,00 que nunca é usado', reasoning: '',
    executed_tools: [
      { index: 0, type: 'browser.search', name: 'browser.search', arguments: '{}', output: '',
        search_results: { results: [
          { title: 'Arroz Tipo 1 5kg - Loja A', url: 'https://loja-a.com.br/arroz', content: 'Por R$ 27,90 à vista' },
          { title: 'Arroz sem preço', url: 'https://loja-b.com.br/arroz', content: 'Consulte' },
          { title: 'Arroz http', url: 'http://loja-c.com.br/arroz', content: 'R$ 20,00' },
        ] } },
      { index: 1, type: 'browser.open', name: 'browser.open', arguments: '{}', output: '',
        search_results: { results: [{ title: 'Arroz 5kg', url: 'https://loja-d.com.br/p', content: 'Oferta R$ 25,49' }] } },
      { index: 2, type: 'python', name: 'python', output: 'R$ 1,00', search_results: { results: [{ url: 'https://x.com.br', content: 'R$ 1,00' }] } },
    ] } }] };
  const ofertas = ofertasGroq(dados, agora);
  assert.deepEqual(ofertas.map((o) => o.preco), [27.9, 25.49]);
  assert.deepEqual(ofertas.map((o) => o.fonte), ['loja-a.com.br', 'loja-d.com.br']);
});
