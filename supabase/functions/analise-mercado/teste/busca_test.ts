import { strict as assert } from 'node:assert';
import fixture from './fixtures/gemini_grounding.json' with { type: 'json' };
import { buscarOfertas, ofertasBrave, ofertasGemini, provedores } from '../busca.ts';

const agora = '2026-10-17T15:00:00.000Z';
const gemini = () => Response.json(fixture);
const brave = () => Response.json({ web: { results: [{ title: 'Arroz por R$ 14,90', url: 'https://brave-loja.example/arroz' }] } });

Deno.test('fixture: só preços ligados a um chunk HTTPS; ignora preço sem fonte e deduplica', () => {
  assert.deepEqual(ofertasGemini(fixture, agora), [
    { preco: 12.9, fonte: 'Mercado A', url: 'https://mercado-a.example/arroz', coletadaEm: agora },
    { preco: 13.5, fonte: 'Mercado B', url: 'https://mercado-b.example/arroz', coletadaEm: agora },
  ]);
});

Deno.test('sem supports/chunks/candidato não aproveita texto gerado nem links citados na prosa', () => {
  for (const dados of [null, {}, { candidates: [] }, { candidates: [{ content: fixture.candidates[0].content }] },
    { candidates: [{ groundingMetadata: fixture.candidates[0].groundingMetadata }] }]) {
    assert.deepEqual(ofertasGemini(dados, agora), []);
  }
});

Deno.test('rejeita segmentos falsos, pensamento, índices inválidos, credenciais e várias fontes', () => {
  for (const mudar of [
    (d: typeof fixture) => { d.candidates[0].groundingMetadata.groundingSupports[0].segment.text = 'Preço fabricado R$ 5,00'; },
    (d: typeof fixture) => { d.candidates[0].groundingMetadata.groundingSupports[0].groundingChunkIndices = [-1]; },
    (d: typeof fixture) => { d.candidates[0].groundingMetadata.groundingSupports[0].groundingChunkIndices = [0, 1]; },
    (d: typeof fixture) => { d.candidates[0].groundingMetadata.groundingChunks[0].web.uri = 'https://usuario:senha@loja.example/'; },
  ]) {
    const d = structuredClone(fixture);
    d.candidates[0].groundingMetadata.groundingSupports = d.candidates[0].groundingMetadata.groundingSupports.slice(0, 1);
    mudar(d);
    assert.deepEqual(ofertasGemini(d, agora), []);
  }
  assert.deepEqual(ofertasGemini({ candidates: [{ content: { parts: [{ text: 'R$ 12,90', thought: true }] },
    groundingMetadata: { groundingChunks: fixture.candidates[0].groundingMetadata.groundingChunks,
      groundingSupports: [{ segment: { text: 'R$ 12,90' }, groundingChunkIndices: [0] }] } }] }, agora), []);
});

Deno.test('offsets são bytes UTF-8 e precisam corresponder ao segmento', () => {
  const conteudo = 'Açúcar: R$ 4,90.';
  const trecho = 'R$ 4,90';
  const inicio = new TextEncoder().encode('Açúcar: ').length;
  const segmento = { text: trecho, partIndex: 0, startIndex: inicio, endIndex: inicio + trecho.length };
  const d = { candidates: [{ content: { parts: [{ text: conteudo }] }, groundingMetadata: {
    groundingChunks: [{ web: { uri: 'https://loja.example/acucar' } }],
    groundingSupports: [{ segment: segmento, groundingChunkIndices: [0] }],
  } }] };
  assert.equal(ofertasGemini(d, agora)[0].preco, 4.9);
  segmento.startIndex--;
  assert.deepEqual(ofertasGemini(d, agora), []);
});

Deno.test('no máximo oito ofertas, sem duplicatas e sem aceitar outro candidato', () => {
  const trechos = Array.from({ length: 12 }, (_, i) => `Loja ${i}: R$ 12,90.`);
  const candidato = { content: { parts: [{ text: trechos.join(' ') }] }, groundingMetadata: {
    groundingChunks: trechos.map((_, i) => ({ web: { uri: `https://loja-${i}.example/produto` } })),
    groundingSupports: trechos.map((text, i) => ({ segment: { text }, groundingChunkIndices: [i] })),
  } };
  assert.equal(ofertasGemini({ candidates: [candidato] }, agora).length, 8);
  assert.deepEqual(ofertasGemini({ candidates: [{}, candidato] }, agora), []);
});

Deno.test('Brave preserva preço, HTTPS, dedupe e tolera JSON inválido', () => {
  const itens = [{ title: 'R$ 14,90', url: 'https://loja.example/a' },
    { title: 'R$ 9,90', url: 'https://loja.example/a' }, { title: 'R$ 8,90', url: 'http://loja.example/' }];
  assert.equal(ofertasBrave({ web: { results: itens } }, agora).length, 1);
  assert.deepEqual(ofertasBrave({ web: { results: {} } }, agora), []);
});

Deno.test('ordem dos provedores depende só das chaves configuradas', () => {
  assert.deepEqual(provedores({ geminiKey: 'teste', braveKey: 'teste' }), ['gemini', 'brave']);
  assert.deepEqual(provedores({ braveKey: 'teste' }), ['brave']);
  assert.deepEqual(provedores({ geminiKey: 'teste' }), ['gemini']);
  assert.deepEqual(provedores({ geminiKey: ' ', braveKey: '' }), []);
});

Deno.test('sem nenhuma chave avisa sem fazer requisição', async () => {
  const resultado = await buscarOfertas('Arroz', '789', {}, () => { throw new Error('Não chamar rede'); }, agora);
  assert.equal(resultado.ofertas.length, 0);
  assert.match(resultado.aviso!, /GEMINI_API_KEY ou BRAVE_SEARCH_API_KEY/);
});

Deno.test('Gemini primário: endpoint, header, google_search, produto e modelo padrão', async () => {
  let chamadas = 0;
  const resultado = await buscarOfertas('Arroz', '789', { geminiKey: 'segredo-teste', braveKey: 'reserva' }, (url, init) => {
    chamadas++;
    assert.equal(String(url), 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent');
    assert.equal(new Headers(init?.headers).get('x-goog-api-key'), 'segredo-teste');
    const corpo = JSON.parse(String(init?.body));
    assert.deepEqual(corpo.tools, [{ google_search: {} }]);
    assert.equal(JSON.parse(corpo.contents[0].parts[0].text).codigoDeBarras, '789');
    assert.equal(init?.method, 'POST');
    return Promise.resolve(gemini());
  }, agora);
  assert.equal(chamadas, 1);
  assert.equal(resultado.ofertas.length, 2);
  assert.equal(resultado.aviso, null);
  assert.ok(!JSON.stringify(resultado).includes('segredo-teste'));
});

Deno.test('modelo configurável', async () => {
  await buscarOfertas('Arroz', '', { geminiKey: 'teste', geminiModel: 'modelo-teste' }, (url) => {
    assert.match(String(url), /models\/modelo-teste:generateContent$/);
    return Promise.resolve(gemini());
  }, agora);
});

for (const caso of ['cota', 'rede', 'json', 'sem_fontes', 'formato']) {
  Deno.test(`fallback Gemini → Brave quando ${caso}`, async () => {
    const chamadas: string[] = [];
    const resultado = await buscarOfertas('Arroz', '789', { geminiKey: 'teste', braveKey: 'reserva' }, (url) => {
      chamadas.push(String(url));
      if (chamadas.length === 2) return Promise.resolve(brave());
      if (caso === 'rede') return Promise.reject(new Error('timeout'));
      return Promise.resolve(caso === 'cota' ? new Response('', { status: 429 }) :
        caso === 'json' ? new Response('não JSON') :
        caso === 'formato' ? Response.json({ error: {} }) : Response.json({ candidates: [{ content: fixture.candidates[0].content }] }));
    }, agora);
    assert.equal(chamadas.length, 2);
    assert.match(chamadas[1], /api.search.brave.com/);
    assert.equal(resultado.ofertas[0].preco, 14.9);
  });
}

Deno.test('só Brave é utilizável e todas as falhas geram aviso sem detalhes sensíveis', async () => {
  assert.equal((await buscarOfertas('Arroz', '', { braveKey: 'teste' }, () => Promise.resolve(brave()), agora)).ofertas.length, 1);
  const erro = await buscarOfertas('Arroz', '', { geminiKey: 'segredo-teste', braveKey: 'reserva' }, () => Promise.resolve(new Response('', { status: 503 })), agora);
  assert.equal(erro.erro, 'busca_indisponivel');
  assert.ok(!JSON.stringify(erro).includes('segredo-teste'));
  const vazio = await buscarOfertas('Arroz', '', { geminiKey: 'teste' }, () => Promise.resolve(Response.json({ candidates: [] })), agora);
  assert.equal(vazio.erro, undefined);
  assert.match(vazio.aviso!, /Não encontramos/);
});
