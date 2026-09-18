# Tutorial para o Lucas - Branch `fix/ia-modelos-atualizados-2026`

## Como pegar essa branch

```bash
git fetch origin
git checkout fix/ia-modelos-atualizados-2026
flutter pub get
flutter run -d chrome
```

---

## O que foi alterado nessa branch

### 1. IA com modelos atualizados (ia_service.dart)
- Modelos antigos (`gemini-1.5-flash`, `gemini-pro`) foram removidos - estavam descontinuados pelo Google e retornavam 404.
- Novos modelos: `gemini-2.5-flash` (primario) e `gemini-2.5-pro` (fallback).
- SDK tenta todos os modelos em cascata automaticamente. Se um falhar, vai pro proximo.
- Se der 503 (servidor sobrecarregado), espera 3 segundos e tenta de novo sozinho.
- Fallback REST apos o SDK: tenta como API Key primeiro, depois como Bearer token.

### 2. IA conectada ao banco de dados (ia_service.dart)
- A funcao `continuarConversa` agora puxa dados reais do Supabase antes de enviar pro Gemini:
  - Estoque do usuario logado
  - Historico de vendas
  - Custos operacionais
- A IA nao pede mais pro usuario colar dados - ela ja tem acesso direto.

### 3. Chat com indicador "digitando" (tela_chat_ia.dart)
- Enquanto a IA processa, aparece "Consultor IA is typing..." com bolinhas animadas.
- Corrigido o bug "null is typing" - adicionado `firstName` e `lastName` ao User da IA.

### 4. Banco multi-tenant blindado (supabase_helper.dart)
- `upsert` substituido por logica explicita de `select` -> `update` ou `insert`.
- Evita conflitos de constraint entre empresas diferentes.

---

## Arquivos modificados

| Arquivo | Mudanca |
|---|---|
| `lib/services/ia_service.dart` | Modelos atualizados, IA conectada ao banco, retry automatico |
| `lib/screens/tela_chat_ia.dart` | Indicador "digitando", fix null typing |
| `lib/services/supabase_helper.dart` | Multi-tenant blindado (sem upsert) |
| `lib/screens/main_layout.dart` | Nova estrutura de layout |
| `lib/screens/tela_dashboard.dart` | Ajustes de UI |
| `lib/screens/tela_estoque.dart` | Ajustes de UI |
| `lib/main.dart` | Atualizacoes gerais |

---

## Chave da API

A chave no `lib/secrets.dart` (`AQ.Ab...`) esta mantida. O codigo aceita ela e envia pro Google via SDK automaticamente.

---

## Para testar

1. Rode `flutter run -d chrome`
2. Va no chat da IA e digite qualquer coisa (ex: "Quantos produtos eu tenho?")
3. Deve aparecer "Consultor IA is typing..." enquanto processa
4. Se der 503, ele tenta de novo sozinho apos 3 segundos
