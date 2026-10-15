// Edge Function `ia-consultor`: proxy seguro para IAs GRATUITAS, com reserva automática.
//
// Por que existe: nenhuma chave de IA pode ir dentro do app (qualquer um extrai de um app
// Web/iPhone/Android). As chaves ficam só aqui, como secrets do Supabase.
//
// Ordem (todas com plano gratuito). Cada uma só entra se o secret existir:
//   1. Gemini      GEMINI_API_KEY      (opcional GEMINI_MODEL)
//   2. Groq        GROQ_API_KEY        (opcional GROQ_MODEL, padrão openai/gpt-oss-120b)
//   3. Ollama      OLLAMA_API_KEY e/ou OLLAMA_URL (padrão https://ollama.com, Ollama Cloud grátis;
//                  ou o seu PC exposto por túnel) — opcional OLLAMA_MODEL
//   4. OpenRouter  OPENROUTER_API_KEY  (opcional OPENROUTER_MODEL, padrão um modelo ":free")
// Se um provedor recusar (cota 429, chave inválida 401/403, fora do ar), passa na hora para o próximo.
//
// Deploy (uma vez, no computador com a CLI do Supabase):
//   npx supabase login
//   npx supabase functions deploy ia-consultor --project-ref drszfkijbemrzzgxvboy
//   npx supabase secrets set GROQ_API_KEY=<chave> --project-ref drszfkijbemrzzgxvboy
//
// verify_jwt fica LIGADO (padrão): só lojista logado chama esta função.
// O app valida a resposta de novo (contrato ia-v1 + aterramento): qualquer número, produto
// ou classe que não esteja nos dados calculados faz a resposta ser descartada.

type Provedor = { nome: string; chamar: (sistema: string, usuario: string, sinal: AbortSignal) => Promise<string | null> };

const env = (k: string) => Deno.env.get(k)?.trim() || undefined;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SISTEMA = `Você é o consultor especialista do APP-CIC: varejo e pequeno comércio no Brasil (mercadinho, padaria,
loja, farmácia, restaurante). Domina giro de estoque, curva ABC, cobertura de estoque, ruptura, margem, markup,
validade, ponto de equilíbrio, reposição e promoção.

REGRAS INEGOCIÁVEIS:
1. Responda EXATAMENTE o que foi perguntado, de forma específica. Nada de texto genérico, saudação, lista de
   recursos do app ou assuntos que não foram pedidos.
2. Use SOMENTE os números, nomes de produto e classes que aparecem no json "metricas" recebido. Copie-os exatamente.
3. NUNCA invente, estime, arredonde, converta ou calcule valores novos. Sem percentuais, quantidades, prazos ou datas
   que não estejam no json. Prefira linguagem qualitativa: "priorize repor", "faça uma promoção".
4. Se faltar dado para responder, diga isso em "dadosAusentes" e responda só o que o json permite.
5. Se a pergunta NÃO for sobre o negócio do lojista (estoque, vendas, produtos, clientes, custos, preços, lucro,
   gestão da loja), responda apenas: "Posso ajudar só com o seu negócio: estoque, vendas, custos e preços." e use
   "tipo": "fora_do_escopo".
6. Português do Brasil, simples e direto, no máximo 4 frases curtas. Termine com uma ação prática quando fizer sentido.
   Cite produtos só pelo nome: nunca escreva produtoId, códigos internos ou nomes de campos do json no texto.
7. Responda SOMENTE com um objeto json válido, sem markdown, no formato:
{"resposta": string, "tipo": "analise" | "fora_do_escopo", "periodo": string|null, "metricas": {nome: número},
 "fontes": [ids de produto citados], "alertas": [string], "dadosAusentes": [string]}
"metricas" só pode conter números que existam no json recebido. "fontes" só IDs que existam no json recebido.`;

function json(status: number, body: unknown, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json', ...extra } });
}

class Recusa extends Error {
  constructor(readonly status: number, readonly codigo = '') {
    super(`HTTP ${status} ${codigo}`);
  }
}

async function postJson(url: string, headers: Record<string, string>, body: unknown, sinal: AbortSignal) {
  const r = await fetch(url, { method: 'POST', signal: sinal, headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });
  if (!r.ok) {
    // Só o código do erro do provedor (ex.: json_validate_failed, rate_limit_exceeded) vai para o diagnóstico.
    let codigo = '';
    try {
      const e = (await r.json())?.error;
      codigo = String(e?.code ?? e?.status ?? e?.type ?? '').replace(/[^\w.-]/g, '').slice(0, 40);
    } catch { /* corpo sem JSON */ }
    throw new Recusa(r.status, codigo);
  }
  return await r.json();
}

// Formato OpenAI (Groq, OpenRouter): mesmo corpo, muda URL/chave/modelo.
function compativelOpenAi(nome: string, url: string, chave: string, modelo: string, extraHeaders: Record<string, string> = {}): Provedor {
  return {
    nome,
    chamar: async (sistema, usuario, sinal) => {
      const d = await postJson(url, { Authorization: `Bearer ${chave}`, ...extraHeaders }, {
        model: modelo, temperature: 0.1, max_tokens: 900, response_format: { type: 'json_object' },
        messages: [{ role: 'system', content: sistema }, { role: 'user', content: usuario }],
      }, sinal);
      return d?.choices?.[0]?.message?.content ?? null;
    },
  };
}

function provedores(): Provedor[] {
  const lista: Provedor[] = [];
  const gemini = env('GEMINI_API_KEY');
  if (gemini) {
    // gemini-2.5-flash foi aposentado para contas novas; os "flash" grandes às vezes dão 503 (alta demanda),
    // então a lista desce até os "lite", que quase sempre respondem.
    const modelos = [env('GEMINI_MODEL'), 'gemini-3.5-flash', 'gemini-flash-lite-latest', 'gemini-3.5-flash-lite', 'gemini-3.8-flash']
      .filter((m, i, a): m is string => !!m && a.indexOf(m) === i);
    lista.push({
      nome: 'gemini',
      chamar: async (sistema, usuario, sinal) => {
        for (const modelo of modelos) {
          try {
            const d = await postJson(`https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`, { 'x-goog-api-key': gemini }, {
              systemInstruction: { parts: [{ text: sistema }] },
              contents: [{ role: 'user', parts: [{ text: usuario }] }],
              generationConfig: { temperature: 0.1, maxOutputTokens: 1024, responseMimeType: 'application/json' },
            }, sinal);
            return d?.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
          } catch (e) {
            // 404 = modelo aposentado; 503 = sobrecarregado: tenta o próximo modelo do Gemini
            if (e instanceof Recusa && (e.status === 404 || e.status === 503)) continue;
            throw e;
          }
        }
        return null;
      },
    });
  }
  const groq = env('GROQ_API_KEY');
  if (groq) lista.push(compativelOpenAi('groq', 'https://api.groq.com/openai/v1/chat/completions', groq, env('GROQ_MODEL') ?? 'openai/gpt-oss-120b'));
  const ollamaKey = env('OLLAMA_API_KEY');
  const ollamaUrl = env('OLLAMA_URL') ?? (ollamaKey ? 'https://ollama.com' : undefined);
  if (ollamaUrl) {
    lista.push({
      nome: 'ollama',
      chamar: async (sistema, usuario, sinal) => {
        const d = await postJson(`${ollamaUrl.replace(/\/$/, '')}/api/chat`, ollamaKey ? { Authorization: `Bearer ${ollamaKey}` } : {}, {
          model: env('OLLAMA_MODEL') ?? 'gpt-oss:120b', stream: false, format: 'json', options: { temperature: 0.1 },
          messages: [{ role: 'system', content: sistema }, { role: 'user', content: usuario }],
        }, sinal);
        return d?.message?.content ?? null;
      },
    });
  }
  const openrouter = env('OPENROUTER_API_KEY');
  if (openrouter) {
    lista.push(compativelOpenAi('openrouter', 'https://openrouter.ai/api/v1/chat/completions', openrouter,
      env('OPENROUTER_MODEL') ?? 'meta-llama/llama-3.3-70b-instruct:free', { 'X-Title': 'APP-CIC' }));
  }
  return lista;
}

// Limite simples por usuário (memória da instância): 12 perguntas/minuto.
const janela = new Map<string, number[]>();
function limitado(chave: string): number {
  const agora = Date.now();
  const lista = (janela.get(chave) ?? []).filter((t) => agora - t < 60_000);
  if (lista.length >= 12) return Math.ceil((60_000 - (agora - lista[0])) / 1000);
  lista.push(agora);
  janela.set(chave, lista);
  return 0;
}

function usuarioDoJwt(req: Request): string {
  try {
    const token = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '');
    const payload = JSON.parse(atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')));
    return String(payload.sub ?? 'anon');
  } catch {
    return 'anon';
  }
}

// Texto livre do lojista: tira caracteres de controle e tentativas de "ignore as regras".
function limparPergunta(p: unknown): string {
  return String(p ?? '')
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/(ignore|desconsidere|esqueça)[^.?!]{0,40}(regras|instru[cç][oõ]es|sistema)/gi, '[removido]')
    .slice(0, 500)
    .trim();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json(405, { erro: 'Método não permitido' });

  const espera = limitado(usuarioDoJwt(req));
  if (espera > 0) return json(429, { erro: 'Muitas perguntas seguidas' }, { 'Retry-After': String(espera) });

  let entrada: Record<string, unknown>;
  try {
    const bruto = await req.text();
    if (bruto.length > 200_000) return json(413, { erro: 'Contexto grande demais' });
    entrada = JSON.parse(bruto);
  } catch {
    return json(400, { erro: 'JSON inválido' });
  }

  const pergunta = limparPergunta(entrada.pergunta);
  const snapshotVersion = String(entrada.snapshotVersion ?? '');
  const atualizadoEm = String(entrada.atualizadoEm ?? '');
  if (!pergunta || !snapshotVersion || !atualizadoEm) return json(400, { erro: 'Campos obrigatórios ausentes' });

  const lista = provedores();
  if (!lista.length) return json(501, { erro: 'IA não configurada no servidor' });

  const contexto = JSON.stringify({
    periodo: entrada.periodo ?? null,
    metricas: entrada.metricas ?? {},
    previsao: entrada.previsao ?? null,
    qualidade: entrada.qualidade ?? {},
  });
  const usuario = `PERGUNTA DO LOJISTA: ${pergunta}\n\nDADOS CALCULADOS em json (única fonte permitida):\n${contexto}`;

  // Orçamento total de 15 s (o app desiste em 18 s), dividido entre os provedores.
  const limite = Date.now() + 15_000;
  const tentativas: string[] = [];
  let textoIa: string | null = null;
  let quem = '';
  for (const [idx, p] of lista.entries()) {
    const restante = limite - Date.now();
    if (restante < 1_500) break;
    // Cada provedor tem no máximo 7 s (o último usa o que sobrar): um Gemini lento não impede o Groq de responder.
    const fatia = idx < lista.length - 1 ? Math.min(restante, 7_000) : restante;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), fatia);
    try {
      textoIa = await p.chamar(SISTEMA, usuario, controller.signal);
      if (textoIa) {
        JSON.parse(textoIa); // fora do formato: tenta o próximo
        quem = p.nome;
        break;
      }
      tentativas.push(`${p.nome}:vazio`);
    } catch (e) {
      tentativas.push(`${p.nome}:${e instanceof Recusa ? `${e.status}${e.codigo ? ':' + e.codigo : ''}` : e instanceof SyntaxError ? 'json' : 'timeout'}`);
      textoIa = null;
    } finally {
      clearTimeout(timer);
    }
  }
  // Diagnóstico nos logs da função (sem dados do lojista): mostra por que cada provedor falhou.
  console.log(JSON.stringify({ ia: quem || 'nenhum', tentativas }));

  if (!textoIa) {
    const so429 = tentativas.length > 0 && tentativas.every((t) => /:429(:|$)/.test(t));
    return json(so429 ? 429 : 503, { erro: 'Nenhuma IA respondeu agora', tentativas });
  }

  try {
    const saida = JSON.parse(textoIa);
    const metricas: Record<string, number> = {};
    for (const [k, v] of Object.entries((saida.metricas ?? {}) as Record<string, unknown>)) {
      if (typeof v === 'number' && Number.isFinite(v)) metricas[k] = v;
    }
    const listaStr = (v: unknown) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string').slice(0, 20) : []);
    return json(200, {
      versaoContrato: 'ia-v1',
      resposta: String(saida.resposta ?? '').trim().slice(0, 900),
      tipo: saida.tipo === 'fora_do_escopo' ? 'fora_do_escopo' : 'analise',
      periodo: typeof saida.periodo === 'string' ? saida.periodo : null,
      metricas,
      fontes: listaStr(saida.fontes),
      alertas: listaStr(saida.alertas),
      dadosAusentes: listaStr(saida.dadosAusentes),
      provedor: quem,
      // Eco do pedido: o app descarta respostas de snapshot diferente.
      snapshotVersion,
      atualizadoEm,
    });
  } catch {
    return json(502, { erro: 'Resposta da IA fora do formato' });
  }
});
