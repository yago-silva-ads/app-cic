# Estoque e Integrações de IA

## Regras
1. **Importação de XML**: Lemos as tags `<det>` para capturar código de barras (`cEAN`), descrição (`xProd`) e valor (`vUnCom`).
2. **Consultas com IA**: Ao escanear o código de barras, a IA auxilia retornando nome sugerido, categoria, validade e outros insights para enriquecimento dos dados do produto antes do salvamento no Supabase.

## Fluxo da SPA
Os dados em memória (como listas de estoque) devem ser puxados na inicialização ou centralizados em um *Provider* caso precisem ser acessados globalmente por múltiplos módulos da SPA.
