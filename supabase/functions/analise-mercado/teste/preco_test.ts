import { deepStrictEqual as assertEquals } from 'node:assert';
import { preco } from '../preco.ts';

Deno.test('normaliza preços brasileiros e ponto decimal', () => {
  assertEquals(preco('R$ 12.90'), 12.90);
  assertEquals(preco('R$ 12,90'), 12.90);
  assertEquals(preco('R$ 1.234,56'), 1234.56);
  assertEquals(preco('R$1234,56'), 1234.56);
  assertEquals(preco('R$ 1.299'), 1299);
});
