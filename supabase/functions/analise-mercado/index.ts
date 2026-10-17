// Pesquisa de preços para o teste de campo. A chave do buscador fica somente
// nos secrets do Supabase; o app recebe apenas ofertas normalizadas e fontes.
import { preco } from './preco.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const env = (k: string) => Deno.env.get(k)?.trim() || undefined;
const json = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });

async function usuarioValido(req: Request): Promise<boolean> {
  const auth = req.headers.get('Authorization') ?? '';
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  if (!token) return false;
  const url = env('SUPABASE_URL');
  const key = env('SUPABASE_ANON_KEY') ?? env('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) return false;
  const r = await fetch(`${url}/auth/v1/user`, { headers: { Authorization: `Bearer ${token}`, apikey: key } });
  return r.ok;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json(405, { erro: 'method_not_allowed' });
  if (!await usuarioValido(req)) return json(401, { erro: 'unauthorized' });
  let produto: { nome?: string; codigo?: string; precoAtual?: number; custo?: number };
  try { produto = (await req.json()).produto ?? {}; } catch { return json(400, { erro: 'json_invalido' }); }
  const nome = String(produto.nome ?? '').trim().slice(0, 120);
  const codigo = String(produto.codigo ?? '').trim().slice(0, 32);
  if (!nome) return json(400, { erro: 'produto_sem_nome' });
  const chave = env('BRAVE_SEARCH_API_KEY');
  if (!chave) return json(200, { ofertas: [], aviso: 'Configure BRAVE_SEARCH_API_KEY nos secrets do Supabase para ativar a busca externa.' });
  const q = encodeURIComponent(`${nome} ${codigo} preço Brasil comprar`);
  const busca = await fetch(`https://api.search.brave.com/res/v1/web/search?q=${q}&country=br&search_lang=pt-br&count=10`, {
    headers: { Accept: 'application/json', 'X-Subscription-Token': chave },
  });
  if (!busca.ok) return json(502, { erro: 'busca_indisponivel' });
  const dados = await busca.json();
  const ofertas: Array<{ preco: number; fonte: string; url: string; coletadaEm: string }> = [];
  for (const item of (dados.web?.results ?? [])) {
    const texto = `${item.title ?? ''} ${item.description ?? ''}`;
    const p = preco(texto);
    if (p == null) continue;
    const url = String(item.url ?? '');
    if (!url || ofertas.some((x) => x.url === url)) continue;
    ofertas.push({ preco: p, fonte: String(item.profile?.long_name ?? item.meta_url?.hostname ?? 'Fonte externa').slice(0, 120), url, coletadaEm: new Date().toISOString() });
  }
  return json(200, { ofertas: ofertas.slice(0, 8), consultadoEm: new Date().toISOString(), aviso: ofertas.length < 2 ? 'Encontramos poucas ofertas; valide o produto e o código de barras antes de alterar o preço.' : null });
});
