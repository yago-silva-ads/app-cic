/** Extrai um preço em reais de texto comercial brasileiro. */
export function preco(texto: string): number | null {
  const m = texto.match(/R\$\s*([0-9][0-9.,]*)/i);
  if (!m) return null;
  const bruto = m[1];
  let normalizado: string;
  if (/,[0-9]{2}$/.test(bruto)) {
    // Vírgula decimal; pontos anteriores são separadores de milhar.
    normalizado = bruto.replace(/\./g, '').replace(',', '.');
  } else if (/\.[0-9]{2}$/.test(bruto)) {
    // Ponto decimal quando há exatamente duas casas no fim.
    normalizado = bruto;
  } else {
    // Ponto com três casas (ex.: 1.299) é separador de milhar.
    normalizado = bruto.replace(/[.,]/g, '');
  }
  const n = Number(normalizado);
  return Number.isFinite(n) && n > 0 && n < 100000 ? n : null;
}
