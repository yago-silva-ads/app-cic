// Pesquisa de preços para o teste de campo. A chave do buscador fica somente
// nos secrets do Supabase; o app recebe apenas ofertas normalizadas e fontes.
import { buscarOfertas } from './busca.ts';

const CORS = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const env = (k: string) => Deno.env.get(k)?.trim() || undefined;
function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin');
  const permitidas = (env('ALLOWED_ORIGINS') ?? '').split(',').map((x) => x.trim()).filter(Boolean);
  return origin && permitidas.includes(origin) ? { ...CORS, 'Access-Control-Allow-Origin': origin, Vary: 'Origin' } : CORS;
}
const json = (status: number, body: unknown, req: Request) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders(req), 'Content-Type': 'application/json' } });

async function usuarioAutenticado(req: Request): Promise<string | null> {
  const bearer = req.headers.get('authorization') ?? '';
  const url = env('SUPABASE_URL');
  if (!url || !/^Bearer\s+\S+$/i.test(bearer)) return null;
  try {
    const r = await fetch(`${url}/auth/v1/user`, { headers: { authorization: bearer, apikey: env('SUPABASE_ANON_KEY') ?? '' } });
    if (!r.ok) return null;
    const u = await r.json();
    return typeof u?.id === 'string' && u.id ? u.id : null;
  } catch {
    return null;
  }
}

const janela = new Map<string, number[]>();
function limitado(uid: string): number {
  const agora = Date.now();
  const lista = (janela.get(uid) ?? []).filter((t) => agora - t < 60_000);
  if (lista.length >= 4) return Math.ceil((60_000 - (agora - lista[0])) / 1000);
  lista.push(agora);
  janela.set(uid, lista);
  return 0;
}

async function reservarCota(req: Request, uid: string): Promise<number> {
  const url = env('SUPABASE_URL');
  const apikey = env('SUPABASE_ANON_KEY');
  if (!url || !apikey) return limitado(uid);
  try {
    const r = await fetch(`${url.replace(/\/$/, '')}/rest/v1/rpc/reservar_cota_ia`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey, authorization: req.headers.get('authorization') ?? '' },
      body: JSON.stringify({ p_limite: 4 }),
      signal: AbortSignal.timeout(2_000),
    });
    if (!r.ok) return limitado(uid);
    const espera = await r.json();
    return Number.isInteger(espera) && espera >= 0 && espera <= 60 ? espera : limitado(uid);
  } catch {
    return limitado(uid);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return json(405, { erro: 'method_not_allowed' }, req);
  const uid = await usuarioAutenticado(req);
  if (!uid) return json(401, { erro: 'unauthorized' }, req);
  const esperaSegundos = await reservarCota(req, uid);
  if (esperaSegundos > 0) return json(429, { erro: 'limite', esperaSegundos }, req);
  let produto: { nome?: string; codigo?: string; precoAtual?: number; custo?: number };
  try { produto = (await req.json()).produto ?? {}; } catch { return json(400, { erro: 'json_invalido' }, req); }
  const nome = String(produto.nome ?? '').trim().slice(0, 120);
  const codigo = String(produto.codigo ?? '').trim().slice(0, 32);
  if (!nome) return json(400, { erro: 'produto_sem_nome' }, req);
  const resultado = await buscarOfertas(nome, codigo, {
    geminiKey: env('GEMINI_API_KEY'), geminiModel: env('GEMINI_MODEL'), braveKey: env('BRAVE_SEARCH_API_KEY'),
  });
  return json(resultado.erro ? 502 : 200, resultado, req);
});
