# Estudo de caso: APP-CIC + LeadForge no teste de campo

## Hipótese

Um pequeno lojista aceita usar o APP-CIC gratuitamente por um período de pesquisa quando a promessa é concreta: registrar estoque e vendas, receber alertas e tomar decisões de preço com dados reais. O site institucional e a automação comercial continuam sendo uma oferta separada, vendida pelo LeadForge quando houver interesse.

## Desenho do piloto

- Participante: uma loja independente, com consentimento e uma conta isolada por `empresa_id`.
- Duração: oito semanas, renovável apenas com autorização do lojista.
- Ativação: cadastrar produtos, custo, preço, estoque mínimo e pelo menos uma venda real.
- Valor entregue: estoque, PDV, auditoria financeira, previsão de reposição e análise de mercado.
- Feedback: formulário dentro do app uma vez por semana, com nota de 1 a 5, checkboxes de áreas usadas, campo livre, recomendação e interesse opcional em site.
- Conversão separada: se o lojista marcar “quero conhecer” ou “quero orçamento”, o LeadForge entra em contato sobre site, criação de páginas e automação de mensagens. O uso do app não depende da compra do site.

## Perguntas da pesquisa

1. O lojista conseguiu cadastrar e vender sem ajuda?
2. Qual alerta ou análise alterou uma decisão de compra, preço ou reposição?
3. A recomendação de preço correspondeu ao mercado observado?
4. O que gerou desconfiança ou trabalho duplicado?
5. O que deve ser corrigido antes de ampliar o piloto?

## Métricas de sucesso

| Métrica | Sinal de sucesso |
|---|---|
| Ativação | 80% dos participantes com 5 produtos e 1 venda na primeira semana |
| Retenção | 60% retornam em quatro semanas |
| Feedback | 1 resposta por loja por semana, sem exigir texto |
| Utilidade | nota média ≥ 4 e um exemplo de decisão tomada |
| Preço | análise com pelo menos 2 fontes e recomendação explicável |
| Conversão | interesse em site medido separadamente, sem condicionar o app |

## Análise preditiva e de mercado

O app calcula a recomendação de forma determinística. O servidor busca ofertas públicas por nome e GTIN, registra URL, fonte, preço e data, remove duplicadas e compara a mediana. A regra sinaliza aumentar quando o preço está mais de 10% abaixo da mediana, reduzir quando está mais de 10% acima e manter dentro dessa faixa. Quando há custo cadastrado, o preço sugerido respeita um piso de 20% de margem bruta. Menos de duas ofertas gera “revisar dados”, nunca uma alteração automática.

Essa análise é uma referência de mercado, não uma promessa de preço. Frete, região, tamanho, marca, promoção e qualidade podem explicar diferenças; o lojista sempre confirma a alteração.

## Integração LeadForge

O evento de interesse no site é capturado no feedback semanal. O próximo passo é sincronizar esse evento com o LeadForge por uma Edge Function autenticada ou webhook assinado, levando somente o consentimento e os dados de contato necessários. O conteúdo do estoque e das vendas fica no tenant do app e não é enviado para prospecção sem autorização explícita.

Contrato sugerido para o evento:

```json
{
  "evento": "interesse_site",
  "origem": "app_cic_teste_campo",
  "empresa_id": "id-interno-nunca-exibido-no-site",
  "interesse": "quero_conhecer",
  "consentimento_contato": true,
  "semana_inicio": "2026-10-12"
}
```

O webhook deve validar assinatura, rejeitar reenvio com o mesmo evento e registrar apenas o status de entrega. O time comercial pode então oferecer site, automação de criação e envio de mensagens sem transformar o app gratuito em uma venda condicionada.
