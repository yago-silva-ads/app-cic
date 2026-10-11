// Edge Function `ia-consultor`: proxy seguro para o Gemini.
//
// Por que existe: a chave do Gemini NUNCA pode ir dentro do app (qualquer um
// extrai de um app Web/iPhone). Ela fica só aqui, como secret do Supabase.
//
// Deploy (uma vez, no computador com a CLI do Supabase):
//   supabase functions deploy ia-consultor --project-ref drszfkijbemrzzgxvboy
//   supabase secrets set GEMINI_API_KEY=<sua chave> --project-ref drszfkijbemrzzgxvboy
//   (opcional) supabase secrets set GEMINI_MODEL=gemini-2.5-flash
//
// verify_jwt fica LIGADO (padrão): só lojista logado chama esta função.
// O app valida a resposta (contrato ia-v1 + aterramento); aqui só limitamos
// o que o modelo recebe e devolvemos o JSON no formato esperado.

const MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-2.5-flash';
const API_KEY = Deno.env.get('GEMINI_API_KEY');

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const SISTEMA = `Você é o consultor financeiro do APP-CIC, para donos de pequenos comércios no Brasil.
REGRAS INEGOCIÁVEIS:
1. Use SOMENTE os números, nomes de produto e classes que aparecem no JSON "metricas" recebido. Copie-os exatamente.
2. NUNCA invente, estime, arredonde, converta ou calcule valores novos. Sem percentuais nem datas que não estejam no JSON.
3. Se faltar dado para responder, diga isso em "dadosAusentes" e responda apenas o que o JSON permite.
4. Não cite quantidades de itens, dias ou prazos como números novos (ex.: "em 3 dias", "10 unidades") se não estiverem no JSON. Prefira linguagem qualitativa: "priorize repor", "faça uma promoção".
5. Linguagem simples, direta, em português do Brasil. No máximo 4 frases.
6. Responda SOMENTE com JSON válido no formato:
{"resposta": string, "tipo": "analise", "periodo": string|null, "metricas": {nome: número}, "fontes": [ids de produto citados], "alertas": [], "dadosAusentes": [string]}
"metricas" só pode conter números que existam no JSON recebido. "fontes" só IDs que existam no JSON recebido.`;

function json(status: number, body: unknown, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json', ...extra },
  });
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json(405, { erro: 'Método não permitido' });
  if (!API_KEY) return json(503, { erro: 'IA não configurada no servidor' });

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

  const pergunta = String(entrada.pergunta ?? '').slice(0, 500);
  const snapshotVersion = String(entrada.snapshotVersion ?? '');
  const atualizadoEm = String(entrada.atualizadoEm ?? '');
  if (!pergunta || !snapshotVersion || !atualizadoEm) return json(400, { erro: 'Campos obrigatórios ausentes' });

  const contexto = JSON.stringify({
    periodo: entrada.periodo ?? null,
    metricas: entrada.metricas ?? {},
    qualidade: entrada.qualidade ?? {},
  });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25_000);
  let resp: Response;
  try {
    resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: 'POST',
      signal: controller.signal,
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': API_KEY },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SISTEMA }] },
        contents: [{ role: 'user', parts: [{ text: `PERGUNTA DO LOJISTA: ${pergunta}\n\nDADOS CALCULADOS (única fonte permitida):\n${contexto}` }] }],
        generationConfig: { temperature: 0.2, maxOutputTokens: 700, responseMimeType: 'application/json' },
      }),
    });
  } catch (e) {
    return json(e instanceof DOMException && e.name === 'AbortError' ? 504 : 502, { erro: 'Provedor de IA indisponível' });
  } finally {
    clearTimeout(timer);
  }

  if (!resp.ok) {
    const status = resp.status === 429 ? 429 : resp.status >= 500 ? 503 : 502;
    return json(status, { erro: 'Provedor de IA recusou a chamada' });
  }

  try {
    const dados = await resp.json();
    const texto: string = dados?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';
    const saida = JSON.parse(texto);
    const metricas: Record<string, number> = {};
    for (const [k, v] of Object.entries((saida.metricas ?? {}) as Record<string, unknown>)) {
      if (typeof v === 'number' && Number.isFinite(v)) metricas[k] = v;
    }
    const lista = (v: unknown) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string') : []);
    return json(200, {
      versaoContrato: 'ia-v1',
      resposta: String(saida.resposta ?? '').trim(),
      tipo: 'analise',
      periodo: typeof saida.periodo === 'string' ? saida.periodo : null,
      metricas,
      fontes: lista(saida.fontes),
      alertas: lista(saida.alertas),
      dadosAusentes: lista(saida.dadosAusentes),
      // Eco do pedido: o app descarta respostas de snapshot diferente.
      snapshotVersion,
      atualizadoEm,
    });
  } catch {
    return json(502, { erro: 'Resposta da IA fora do formato' });
  }
});
