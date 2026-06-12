# Guia de Análise de Dados - Supabase, Firebase e DataStudio

## 📊 Visão Geral dos Recursos

Seu projeto utiliza três plataformas poderosas para análise de dados:

| Plataforma | Status | Propósito | Acesso |
|-----------|--------|----------|--------|
| **Supabase** | ✅ Ativo | Armazenar dados do estoque e vendas | Desenvolvedor + Usuário |
| **Firebase Analytics** | ⚠️ Parcial | Rastrear eventos e comportamento | Desenvolvedor |
| **DataStudio** | ⏳ Planejado | Visualizar dados em dashboards | Usuário Final |

---

## 1️⃣ SUPABASE - Para o Desenvolvedor

### Como Acessar:
1. Acesse: https://app.supabase.com/
2. Login com suas credenciais
3. Selecione o projeto **app-cic**

### Dados Disponíveis:

#### Tabela: `produtos`
Contém todo o estoque:
```
- codigo (PK)
- nome
- lote
- quantidade
- valor_compra
- markup
- valor_venda
- origem
- data_entrada
- data_validade
- vendidas
```

#### Tabela: `historico_vendas`
Registro completo de todas as vendas:
```
- id (PK)
- produto_codigo (FK)
- quantidade_vendida
- valor_unitario
- data_venda (timestamp automático)
```

### Queries Úteis (SQL no Supabase):

**1. Total vendido por dia:**
```sql
SELECT 
    DATE(data_venda) as data,
    SUM(quantidade_vendida * valor_unitario) as faturamento,
    COUNT(*) as qtd_vendas
FROM historico_vendas
GROUP BY DATE(data_venda)
ORDER BY data DESC;
```

**2. Produtos mais vendidos:**
```sql
SELECT 
    p.nome,
    COUNT(hv.id) as qtd_vendas,
    SUM(hv.quantidade_vendida) as total_qtd
FROM historico_vendas hv
JOIN produtos p ON hv.produto_codigo = p.codigo
GROUP BY p.codigo, p.nome
ORDER BY qtd_vendas DESC
LIMIT 10;
```

**3. Faturamento por produto:**
```sql
SELECT 
    p.nome,
    SUM(hv.quantidade_vendida * hv.valor_unitario) as faturamento,
    SUM(hv.quantidade_vendida) as qtd
FROM historico_vendas hv
JOIN produtos p ON hv.produto_codigo = p.codigo
GROUP BY p.codigo, p.nome
ORDER BY faturamento DESC;
```

**4. Margem de lucro por venda:**
```sql
SELECT 
    p.nome,
    hv.valor_unitario,
    p.valor_compra,
    (hv.valor_unitario - p.valor_compra) as margem_unitaria,
    ((hv.valor_unitario - p.valor_compra) / p.valor_compra * 100) as margem_percentual
FROM historico_vendas hv
JOIN produtos p ON hv.produto_codigo = p.codigo
ORDER BY margem_percentual DESC;
```

### Como Usar no Código (Exemplos):

**Criar uma tela de estatísticas avançadas:**
```dart
// No seu serviço, adicione métodos como:
static Future<Map> getRelatorioVendas() async {
  final response = await supabase.rpc('get_relatorio_vendas');
  return response;
}
```

---

## 2️⃣ FIREBASE ANALYTICS - Para o Desenvolvedor

### Como Acessar:
1. Acesse: https://console.firebase.google.com/
2. Selecione o projeto **app-cic**
3. Vá em: Analytics → Dashboard

### Eventos Rastreados Atualmente:
- `venda_realizada` (código, quantidade, valor)

### Como Expandir o Rastreamento:

**Adicione mais eventos no código:**
```dart
// 1. Quando usuário entra no app
FirebaseAnalytics.instance.logAppOpen();

// 2. Quando usuário cadastra produto
FirebaseAnalytics.instance.logEvent(
  name: 'produto_cadastrado',
  parameters: {
    'codigo': codigo,
    'preco_venda': preco,
    'categoria': categoria,
  },
);

// 3. Quando acessa dashboard
FirebaseAnalytics.instance.logEvent(
  name: 'dashboard_aberto',
  parameters: {
    'total_produtos': estoque.length,
    'total_faturamento': faturamento,
  },
);

// 4. Quando usa consultor IA
FirebaseAnalytics.instance.logEvent(
  name: 'consultor_ia_usado',
  parameters: {
    'tipo_analise': 'estoque',
  },
);
```

### Painéis Recomendados:

**1. Dashboard de Vendas em Tempo Real:**
- Vendas por hora/dia
- Produto mais vendido
- Faturamento total

**2. Funil de Usuário:**
- Entrada → Cadastro → Venda → Dashboard

**3. Retenção:**
- Quantos usuários retornam diariamente/semanalmente

---

## 3️⃣ DATASTUDIO - Para o Usuário Final

### O que é?
Google DataStudio conecta suas bases de dados e cria **dashboards visuais interativos** que o usuário pode compartilhar e acessar pela web.

### Como Configurar (Você, como Desenvolvedor):

#### Passo 1: Criar Conta de Serviço Google Cloud
```
1. Acesse: https://console.cloud.google.com/
2. Crie um novo projeto
3. Ative BigQuery API
4. Crie uma conta de serviço com credenciais JSON
5. Compartilhe o Supabase com essa conta
```

#### Passo 2: Importar Dados do Supabase para BigQuery
```
1. Vá em: https://cloud.google.com/bigquery/docs/integrations
2. Crie uma tabela no BigQuery com os dados do Supabase
3. (Alternativa) Use Supabase → Google Sheets → DataStudio
```

#### Passo 3: Criar Dashboard no DataStudio
```
1. Acesse: https://datastudio.google.com/
2. Crie novo relatório
3. Adicione a fonte de dados (BigQuery/Sheets)
4. Crie visualizações:
   - Gráfico de vendas por dia
   - Top 10 produtos
   - Margem de lucro por produto
   - Faturamento vs Meta
5. Compartilhe com o usuário por link
```

### Dashboard Recomendado para o Usuário:

```
┌─────────────────────────────────────────┐
│   📊 DASHBOARD DE VENDAS - CIC          │
├─────────────────────────────────────────┤
│                                         │
│  💰 Faturamento Hoje    │  📦 Estoque  │
│  R$ 1.250,00           │  45 itens    │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Vendas por Dia (Últimos 7 dias)       │
│  [Gráfico de linha]                    │
│                                         │
├─────────────────────────────────────────┤
│                                         │
│  Top 5 Produtos Mais Vendidos          │
│  1. Produto A - 150 unidades           │
│  2. Produto B - 89 unidades            │
│  3. Produto C - 56 unidades            │
│                                         │
├─────────────────────────────────────────┤
│  Margem de Lucro Média: 35%             │
│  Meta Mensal: R$ 50.000 (60%)          │
└─────────────────────────────────────────┘
```

---

## 🎯 Plano de Implementação (Passo a Passo)

### Fase 1: Desenvolvedor (Você)

#### ✅ Já Feito:
- [x] Supabase conectado
- [x] Banco de dados estruturado
- [x] Firebase Analytics iniciado
- [x] Um evento sendo rastreado

#### ⏳ Próximos Passos:

1. **Expandir Firebase Analytics** (1-2 horas)
   - Adicionar eventos conforme código acima
   - Criar view customizada no Firebase

2. **Criar Serviço de Relatórios** (2-3 horas)
   ```dart
   // Novo arquivo: lib/services/relatorio_service.dart
   class RelatorioService {
     static Future<Map> getEstatisticasVendas() { ... }
     static Future<Map> getProdutosMaisVendidos() { ... }
     static Future<Map> getMargemLucro() { ... }
   }
   ```

3. **Tela de Estatísticas Avançadas** (3-4 horas)
   - Integrar com Supabase queries
   - Mostrar gráficos adicionais
   - Permitir filtros por data/produto

### Fase 2: Para o Usuário Final

1. **Criar Dashboard DataStudio** (2-3 horas)
   - Conectar dados do Supabase
   - Criar visualizações
   - Compartilhar link

2. **Documentação do Usuário**
   - Como acessar o dashboard
   - Como interpretar os dados
   - Metas e KPIs

3. **Treinamento**
   - Mostrar como usar
   - Explicar insights
   - Responder dúvidas

---

## 💡 Exemplos de Insights que Pode Oferecer

### 1. **Análise ABC Dinâmica**
```
"Seus produtos A (20%) geram 80% do faturamento.
Foque em manter estoque alto desses itens."
```

### 2. **Previsão de Demanda**
```
"Baseado no histórico, você venderá ~200 unidades
do Produto X na próxima semana. Reponha o estoque!"
```

### 3. **Oportunidade de Margem**
```
"Você deixou R$ 5.000 em ganho ao vender o Produto Y
com markup menor que o usual. Reveja sua estratégia."
```

### 4. **Sazonalidade**
```
"Sexta-feira registra 40% mais vendas que segunda.
Prepare-se com mais estoque no final da semana!"
```

---

## 📞 Resumo Rápido

### Para o Desenvolvedor:
- ✅ **Supabase**: Consultar dados raw, criar queries customizadas
- ✅ **Firebase**: Rastrear comportamento, eventos, retenção
- ✅ **DataStudio**: Conectar dados e criar dashboards para usuários

### Para o Usuário Final:
- 📊 **Dashboard DataStudio**: Ver vendas, estoque, tendências
- 📈 **Insights IA**: Análises preditivas personalizadas
- 📱 **App**: Continuar usando normalmente, dados fluindo

---

## 🔗 Links Úteis

| Recurso | URL |
|---------|-----|
| Supabase Console | https://app.supabase.com/ |
| Firebase Console | https://console.firebase.google.com/ |
| DataStudio | https://datastudio.google.com/ |
| BigQuery | https://console.cloud.google.com/bigquery |
| Supabase Docs | https://supabase.com/docs |
| Firebase Analytics | https://firebase.google.com/docs/analytics |

---

**Última atualização**: Junho 2026
**Versão**: 1.0
**Responsável**: Você (Desenvolvedor do app-cic)
