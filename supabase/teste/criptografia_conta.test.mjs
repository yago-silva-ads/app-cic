// Testa supabase/criptografia_conta.sql num Postgres real em memória (PGlite + pgcrypto),
// com Vault, auth.uid() e os papéis anon/authenticated simulados como no Supabase.
//
// Uso (numa pasta qualquer fora do repo):
//   npm install @electric-sql/pglite@0.5.10
//   node <repo>/supabase/teste/criptografia_conta.test.mjs <repo>/supabase/criptografia_conta.sql
// Rode o node a partir da pasta onde instalou o PGlite.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import assert from 'node:assert/strict';

const req = createRequire(pathToFileURL(process.cwd() + '/'));
const { PGlite } = await import(pathToFileURL(req.resolve('@electric-sql/pglite')));
const { pgcrypto } = await import(pathToFileURL(req.resolve('@electric-sql/pglite/contrib/pgcrypto')));

const migracao = readFileSync(process.argv[2], 'utf8');
const db = new PGlite({ extensions: { pgcrypto } });
const ok = (m) => console.log('ok  ', m);
const A = '11111111-1111-1111-1111-111111111111';
const B = '22222222-2222-2222-2222-222222222222';

await db.exec(`
  CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN;
  CREATE SCHEMA extensions; CREATE SCHEMA auth; CREATE SCHEMA vault;
  CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE
    AS $$ SELECT nullif(current_setting('teste.uid', true), '')::uuid $$;
  GRANT USAGE ON SCHEMA auth TO anon, authenticated;
  GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;
  CREATE TABLE vault.secrets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text UNIQUE, secret text, description text);
  CREATE VIEW vault.decrypted_secrets AS SELECT id, name, secret AS decrypted_secret FROM vault.secrets;
  CREATE FUNCTION vault.create_secret(s text, n text, d text) RETURNS uuid LANGUAGE sql
    AS $$ INSERT INTO vault.secrets(name, secret, description) VALUES (n, s, d) RETURNING id $$;
  CREATE FUNCTION vault.update_secret(i uuid, s text) RETURNS void LANGUAGE sql
    AS $$ UPDATE vault.secrets SET secret = s WHERE id = i $$;
  CREATE TABLE public.contas_estabelecimento (
    empresa_id uuid PRIMARY KEY DEFAULT auth.uid(),
    dados jsonb NOT NULL DEFAULT '{}',
    atualizado_em timestamptz NOT NULL DEFAULT now());
  ALTER TABLE public.contas_estabelecimento ENABLE ROW LEVEL SECURITY;
  CREATE POLICY propria ON public.contas_estabelecimento
    USING (empresa_id = auth.uid()) WITH CHECK (empresa_id = auth.uid());
  GRANT USAGE ON SCHEMA public TO anon, authenticated;
  GRANT SELECT, INSERT, UPDATE ON public.contas_estabelecimento TO authenticated;
`);
// Loja gravada em texto aberto antes da migração.
await db.query(`INSERT INTO contas_estabelecimento (empresa_id, dados) VALUES ($1, $2)`,
  [B, { nomeFantasia: 'Loja B', documentoNumero: '99.999.999/0001-99', dadosPix: { chave: 'pix-b@x.com' } }]);

await db.exec(migracao);
ok('migração aplicada');

const bruto = async (id) =>
  (await db.query(`SELECT dados, dados_cifrados FROM contas_estabelecimento WHERE empresa_id = $1`, [id])).rows[0];
const comoUsuario = async (uid, sql, params = []) => {
  await db.exec(`SET ROLE authenticated; SELECT set_config('teste.uid', '${uid}', false);`);
  try {
    return (await db.query(sql, params)).rows;
  } finally {
    await db.exec(`RESET ROLE`);
  }
};
const lerConta = async (uid) => (await comoUsuario(uid, `SELECT minha_conta()`))[0].minha_conta;

const b = await bruto(B);
assert.equal(b.dados.documentoNumero, undefined);
assert.equal(b.dados.nomeFantasia, 'Loja B');
assert.ok(b.dados_cifrados);
ok('dados antigos: loja existente foi cifrada; nome continua aberto');

const contaA = {
  nomeFantasia: 'Mercadinho A', documentoNumero: '12.345.678/0001-90', telefone: '11999990000', email: 'a@loja.com',
  dadosPix: { tipoChave: 'CNPJ', chave: '12345678000190', titularNome: 'Fulano' },
  dadosBancarios: { banco: '341', agencia: '0001', conta: '12345-6' },
  configPDV: { operadorNome: 'Caixa' },
};
await comoUsuario(A, `SELECT salvar_minha_conta($1)`, [contaA]);
const a = await bruto(A);
for (const k of ['documentoNumero', 'telefone', 'email', 'dadosPix', 'dadosBancarios']) assert.equal(a.dados[k], undefined, k);
const bytes = Buffer.from(a.dados_cifrados).toString('latin1');
for (const s of ['12.345.678', '11999990000', 'a@loja.com', '12345-6', 'Fulano']) assert.ok(!bytes.includes(s), 'vazou ' + s);
ok('gravação: campos sensíveis fora do JSON aberto e ausentes no texto cifrado');

assert.deepEqual(await lerConta(A), contaA);
ok('leitura: minha_conta() devolve exatamente o que foi salvo');

const lidaB = await lerConta(B);
assert.equal(lidaB.nomeFantasia, 'Loja B');
assert.equal(lidaB.dadosPix.chave, 'pix-b@x.com');
assert.equal(lidaB.email, undefined);
ok('isolamento: cada loja lê só a própria conta');

await comoUsuario(A, `UPDATE contas_estabelecimento SET dados = dados || '{"telefone":"1100000000"}' WHERE empresa_id = $1`, [A]);
let lida = await lerConta(A);
assert.equal(lida.telefone, '1100000000');
assert.equal(lida.dadosPix.chave, '12345678000190');
assert.equal(lida.dadosBancarios.conta, '12345-6');
await comoUsuario(A, `UPDATE contas_estabelecimento SET dados = dados || '{"nomeFantasia":"Mercadinho A2"}' WHERE empresa_id = $1`, [A]);
lida = await lerConta(A);
assert.equal(lida.nomeFantasia, 'Mercadinho A2');
assert.equal(lida.email, 'a@loja.com');
ok('gravação parcial: troca um campo sem apagar Pix, banco nem e-mail');

await db.exec(`SET ROLE anon`);
await assert.rejects(db.query(`SELECT minha_conta()`), /permission denied/);
await db.exec(`RESET ROLE`);
await assert.rejects(comoUsuario('', `SELECT minha_conta()`), /SEM_SESSAO/);
await assert.rejects(comoUsuario(A, `SELECT private.chave_conta()`), /permission denied/);
ok('anon sem permissão, sem sessão recebe SEM_SESSAO e lojista não lê a chave');

const antes = (await bruto(A)).dados_cifrados;
await db.exec(`
  BEGIN;
  CREATE TEMP TABLE t AS SELECT empresa_id,
    extensions.pgp_sym_decrypt(dados_cifrados, private.chave_conta())::jsonb AS s
    FROM public.contas_estabelecimento WHERE dados_cifrados IS NOT NULL;
  SELECT vault.update_secret((SELECT id FROM vault.secrets WHERE name = 'app_cic_chave_conta'),
                             encode(extensions.gen_random_bytes(32), 'hex'));
  UPDATE public.contas_estabelecimento c SET dados_cifrados = NULL, dados = c.dados || t.s
    FROM t WHERE t.empresa_id = c.empresa_id;
  COMMIT;`);
assert.notDeepEqual((await bruto(A)).dados_cifrados, antes);
assert.equal((await lerConta(A)).dadosBancarios.conta, '12345-6');
assert.equal((await lerConta(B)).dadosPix.chave, 'pix-b@x.com');
ok('rotação de chave: tudo recifrado com a chave nova e legível');

await db.exec(migracao);
assert.equal((await lerConta(A)).email, 'a@loja.com');
ok('migração pode rodar de novo sem estragar nada');

console.log('\nTodos os testes de criptografia passaram.');
