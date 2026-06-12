# 🔍 Referência Rápida - Supabase + Firebase + DataStudio

## 📊 Fluxo de Dados Completo

```
┌─────────────────────────────────────────────────────────────────┐
│                        SEU APP (Flutter)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Usuário cadastra produto/vende                                │
│            ↓                                                    │
│  RelatorioService extrai dados em tempo real                   │
│            ↓                                                    │
│  ┌─────────────────────────────────────────────────────┐       │
│  │  Exibe na Tela: EstatisticasAvancadasWidget          │       │
│  │  • Faturamento Total                                │       │
│  │  • ROI, Margem, Previsão                           │       │
│  │  • Top 5 Produtos                                  │       │
│  │  • Alerta de Falta                                 │       │
│  └─────────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
            ↓                        ↓                   ↓
     ┌──────────────┐      ┌───────────────┐    ┌────────────────┐
     │  Supabase    │      │   Firebase    │    │  Google Cloud  │
     │ (Banco de    │      │  (Rastreio)   │    │  (Sync dados)  │
     │   Dados)     │      │               │    │                │
     └──────────────┘      └───────────────┘    └────────────────┘
            ↓                        ↓                   ↓
     ┌──────────────────────────────────────────────────────────┐
     │          GOOGLE DATASTUDIO                              │
     │  (Dashboard Online para Usuário Final)                  │
     └──────────────────────────────────────────────────────────┘
```

---

## 📱 O Que Fazer Agora

### PASSO 1: Você (Desenvolvedor)

```bash
# 1. Verifique se os arquivos existem:
# ✅ lib/services/relatorio_service.dart
# ✅ lib/widgets/estatisticas_avancadas_widget.dart

# 2. Rode o app e teste:
flutter clean
flutter pub get
flutter run

# 3. Abra o Dashboard e procure por "Estatísticas" (ou veja dados em cards)
```

### PASSO 2: Expandir Firebase Analytics

Nos arquivos indicados, adicione os eventos conforme [IMPLEMENTACAO_RECURSOS.md](IMPLEMENTACAO_RECURSOS.md)

### PASSO 3: Para Usuário Final

Prepare o DataStudio Dashboard seguindo [GUIA_ANALISE_DADOS.md](GUIA_ANALISE_DADOS.md) e compartilhe [GUIA_USUARIO_ANALISES.md](GUIA_USUARIO_ANALISES.md)

---

## 🔧 Métodos do RelatorioService (Referência Rápida)

| Método | Retorna | Uso |
|--------|---------|-----|
| `getEstatisticasGerais()` | Faturamento, vendas, ticket médio | Home screen |
| `getProdutosMaisVendidos(limit)` | Top N produtos | Relatório |
| `getMargemLucroMedia()` | % e valor de margem | Dashboard |
| `getFaturamentoPorPeriodo(dias)` | Faturamento dia a dia | Gráfico |
| `getProdutosEmFalta(minimo)` | Produtos com estoque baixo | Alerta |
| `getComposicaoEstoque()` | Distribuição por origem | Gráfico pizza |
| `getROI()` | Retorno sobre investimento | KPI |
| `getPrevisaoVendas(dias)` | Previsão por média móvel | Planejamento |

### Exemplo de Uso Rápido:

```dart
// Pegar todos os dados para dashboard:
final roi = await RelatorioService.getROI();
print('Seu ROI é: ${roi['roi_percentual']}%');

// Em um ListView:
final topProdutos = await RelatorioService.getProdutosMaisVendidos(limit: 10);
for (var p in topProdutos) {
  print('${p['codigo']}: R\$ ${p['total_faturado']}');
}
```

---

## 🎨 Estrutura do EstatisticasAvancadasWidget

```
EstatisticasAvancadasWidget (Pull-to-refresh)
├── _buildResumoExecutivo()
│   ├─ Gradiente azul
│   ├─ Total faturado
│   ├─ ROI acumulado
│   └─ Ticket médio
├── _buildKPIsPrincipais()
│   ├─ Margem de Lucro
│   ├─ ROI
│   ├─ Lucro Total
│   └─ Previsão 7 dias
├── _buildTopProdutos()
│   └─ Top 5 com faturamento
└── _buildProdutosEmFalta() [se houver]
    └─ Alerta em vermelho
```

---

## 🌐 Firebase Analytics - Eventos Novos

```dart
// Evento: Produto Cadastrado
FirebaseAnalytics.instance.logEvent(
  name: 'produto_cadastrado',
  parameters: {
    'codigo': 'ABC123',
    'preco_venda': 99.90,
    'quantidade': 10,
  },
);

// Evento: Dashboard Aberto
FirebaseAnalytics.instance.logEvent(
  name: 'dashboard_aberto',
  parameters: {'timestamp': DateTime.now().toString()},
);

// Evento: IA Consultada
FirebaseAnalytics.instance.logEvent(
  name: 'consultor_ia_pergunta',
  parameters: {'tema': 'estoque'},
);
```

### Visualizar em Firebase:

1. Console Firebase → Seu Projeto
2. Analytics → Dashboard
3. Veja em tempo real quais eventos estão sendo rastreados

---

## 📊 DataStudio Setup (Checklist)

- [ ] Criar conta Google Cloud
- [ ] Ativar BigQuery API
- [ ] Criar tabela no BigQuery com dados do Supabase
- [ ] Criar novo relatório em DataStudio
- [ ] Conectar fonte de dados (BigQuery)
- [ ] Adicionar visualizações:
  - [ ] Gráfico de vendas por dia
  - [ ] Top 10 produtos
  - [ ] Margem de lucro
  - [ ] Faturamento vs Meta
- [ ] Compartilhar link com usuário

---

## 🐛 Se Algo Não Funcionar

| Problema | Solução |
|----------|---------|
| Widget não aparece | Verificar import, pubspec atualizado |
| Dados vazios | Verificar Supabase conectado, estoque preenchido |
| Firebase não rastreia | Verificar Firebase.initializeApp() no main.dart |
| Consultas lentas | Adicionar índices no Supabase |
| DataStudio sem dados | Verificar BigQuery sincronizado |

---

## 📈 Interpretar os Dados (Para Usuário)

### Seu ROI está em 25%
✅ Bom! Para cada R$ 100 investido, você ganha R$ 25

### Margem de lucro caiu de 35% para 20%
⚠️ Alerta! Pode ser que tenha comprado mais caro ou vendido mais barato

### Previsão para 7 dias: R$ 5.000
📊 Planeje estoque e custos com base nisso

### Produto A é 60% das vendas
🎯 Foco: Mantenha sempre em estoque!

---

## 🚀 Próximas Melhorias (Roadmap)

### Curto Prazo (1-2 semanas)
- [ ] Integrar widget no Dashboard
- [ ] Expandir Firebase Analytics
- [ ] Criar Dashboard DataStudio

### Médio Prazo (1 mês)
- [ ] Exportar PDF de relatórios
- [ ] Cache local de dados
- [ ] Notificações automáticas

### Longo Prazo (2+ meses)
- [ ] Previsão com Machine Learning
- [ ] Comparação com concorrentes
- [ ] Integração com sistemas de nota fiscal

---

## 📞 Resumão em Uma Linha

**Você agora tem análise de dados em tempo real no app + será possível compartilhar dashboards online com os dados consolidados.**

---

## 📖 Documentos Completos

- 📘 [GUIA_ANALISE_DADOS.md](GUIA_ANALISE_DADOS.md) - Tudo técnico
- 🎯 [IMPLEMENTACAO_RECURSOS.md](IMPLEMENTACAO_RECURSOS.md) - Como integrar
- 👤 [GUIA_USUARIO_ANALISES.md](GUIA_USUARIO_ANALISES.md) - Para o usuário

---

**Última atualização**: Junho 2026
**Versão**: 1.0
**Status**: ✅ Pronto para uso
