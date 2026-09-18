# Cálculos de Estoque e Margens

## Preço de Compra vs Preço de Venda
No nosso sistema, quando um produto entra, ele tem o `valorCompra`. O `valorVenda` pode ser ditado manualmente ou calculado por um `markup`.

> Cuidado: O `valor_compra` pode flutuar se houverem `Aquisições` de lotes diferentes. Usamos o cálculo de **Custo Médio Ponderado**.

## Curva ABC de Inventário
A Inteligência Artificial e a tela de Dashboard utilizam o conceito de **Curva ABC** para classificar produtos:
- **Classe A (20%)**: Produtos que geram 80% do lucro. Têm a maior margem de lucro (`valorVenda` - `valorCompra`). Jamais podem faltar.
- **Classe B (30%)**: Produtos intermediários. Lucro considerável.
- **Classe C (50%)**: Produtos que vendem muito pouco ou têm margens espremidas.

Ao desenvolver na IA (`tela_inteligencia_web.dart`), forneça os dados de estoque e force-a a analisar usando esse princípio.
