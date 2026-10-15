# APP-CIC

O APP-CIC ajuda pequenos lojistas a vender, controlar o estoque e entender os números do negócio em um só aplicativo. Funciona na web e no Android, com leitura de códigos de barras, frente de caixa e um assistente orientado pelos dados calculados da loja.

É voltado a quem precisa acompanhar produtos, validade, reposição e custos sem depender de várias planilhas. O modo demonstração permite conhecer o fluxo com dados em memória.

## Funcionalidades e vantagens

- **PDV:** carrinho, registro da forma de pagamento, abertura e fechamento de caixa. A venda registra histórico e baixa o estoque na mesma transação, reduzindo divergências de saldo.
- **Leitor de código de barras GS1:** leitura pela câmera e identificação pelo código para agilizar cadastro e busca. Reconhecer o código não garante a disponibilidade de todos os dados comerciais do produto.
- **Estoque com validade:** saldo atual, lote, custo, preço, estoque mínimo, categoria e movimentações. Também há importação por XML de NF-e.
- **Curva ABC:** classificação calculada para identificar produtos de maior participação nas vendas e priorizar a atenção. O modo projetado é separado do realizado.
- **Assistente com IA e proteção contra números inventados:** perguntas objetivas usam cálculos locais. Análises abertas passam por uma trava de aterramento; inconsistências detectadas são descartadas e substituídas por dados calculados com aviso. A proteção reduz alucinações, mas não garante toda afirmação em linguagem natural.
- **Alertas:** estoque baixo, validade e situações que merecem atenção, com histórico e marcação de leitura.
- **Custos e ponto de equilíbrio:** despesas fixas e variáveis e estimativa de faturamento necessário para cobri-las, conforme a margem usada no cálculo. Projeção não é receita já realizada.

O branch `ia-gratis`, em integração, acrescenta previsão de demanda por média móvel de 30 dias e a cadeia Gemini → Groq → Ollama → OpenRouter. Nesta base local (`643fdd6`), a Edge Function ainda usa Gemini e DeepSeek opcional. Os diagramas identificam essas diferenças.

## Como funciona o assistente

O app calcula estoque, atenção e ABC antes de consultar um modelo. Perguntas objetivas podem ser respondidas diretamente. Para análises abertas, envia contexto calculado e sessão autenticada à Edge Function `ia-consultor`, que chama o provedor de IA.

A resposta passa por validação do contexto antes de ser exibida. Se faltar configuração, houver timeout ou inconsistência detectada, o app mostra os dados calculados disponíveis. Isso exige dados confiáveis já carregados; não é uma promessa de sincronização offline completa.

As camadas gratuitas têm limites. Ollama precisa de um servidor ligado e alcançável pela Edge Function; o computador do desenvolvedor desligado não oferece esse serviço. [Veja a sequência completa](docs/arquitetura/sequencia-assistente.md).

## Segurança

- **RLS por loja:** os SQLs definem isolamento por `empresa_id = auth.uid()`. As funções de escrita validam o usuário e usam sua loja. A proteção depende das migrações e permissões aplicadas no Supabase.
- **Credenciais:** o Flutter recebe a URL e a chave pública `anon`. Chaves de IA e `service_role` ficam no servidor, nunca em `--dart-define`, imagens ou arquivos públicos.
- **Senha forte:** a base local exige ao menos oito caracteres. O endurecimento de senha e autenticação pertence ao branch `seguranca-app`, a integrar. No painel Supabase, configurar confirmação de e-mail, política de senha e limites de tentativas; o controle no cliente não substitui o servidor.
- **CSP e headers web:** a base define `X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy` e `Permissions-Policy` no Vercel. A CSP pertence à integração de segurança; conferir sua compatibilidade com Flutter, câmera e Supabase antes de publicar.
- **Build ofuscado:** releases Android/iOS devem usar `--obfuscate --split-debug-info`. Guardar os símbolos fora dos artefatos públicos. Ofuscação dificulta a leitura do binário, mas não substitui RLS nem protege segredos embutidos.

Esta documentação não verificou o painel nem a configuração implantada. Após integrar `seguranca-app`, conferir também logout, limpeza de estado, mensagens de autenticação e ausência de logs sensíveis. Consulte o [modelo de dados e políticas](docs/arquitetura/modelo-de-dados.md).

## Stack

| Camada | Tecnologia |
| --- | --- |
| Aplicativo | Flutter / Dart, web e Android |
| Regras de negócio | Pacote local `packages/cic_domain`, em Dart |
| Autenticação e dados | Supabase Auth, PostgreSQL, RLS e RPCs |
| Backend de IA | Supabase Edge Functions, TypeScript / Deno |
| Leitura e importação | `mobile_scanner`, integração de leitor web e parser XML |
| Publicação web | Vercel, configurado em `vercel.json` |

## Como rodar

### Pré-requisitos

- Flutter SDK com Dart compatível com `^3.11.4`, conforme `pubspec.yaml`.
- Chrome ou Edge para web; Android SDK e aparelho/emulador para Android.
- Câmera e permissão de uso para testar o leitor.
- Projeto Supabase configurado para dados reais.

### Aplicativo

Na raiz do repositório:

```sh
flutter doctor
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON_PUBLICA
```

Para Android, selecione o identificador retornado por `flutter devices`:

```sh
flutter devices
flutter run -d ID_DO_DISPOSITIVO --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON_PUBLICA
```

Os valores acima são exemplos. `lib/core/config.dart` possui configurações públicas padrão; use os parâmetros para apontar para seu próprio ambiente. A opção de demonstração na tela de acesso permite explorar o app com dados em memória.

### Supabase

1. Configure Auth e as URLs de redirecionamento. Ative confirmação de e-mail, política de senha e limites de autenticação.
2. Obtenha o schema inicial de `produtos`, `historico_vendas` e `custos_operacionais` e revise as evoluções em `supabase/`. Os SQLs locais não constituem um bootstrap completo de banco vazio. Não execute todos em ordem alfabética: há scripts de limpeza e relações antigas substituídas pela v3.
3. Aplique as migrações revisadas e confira o isolamento com duas contas distintas. Veja as fontes no [modelo de dados](docs/arquitetura/modelo-de-dados.md).
4. Cadastre os secrets no painel de Edge Functions e publique `ia-consultor`. Nesta base, a função lê `GEMINI_API_KEY`, `GEMINI_MODEL` e, opcionalmente, `DEEPSEEK_API_KEY`/`DEEPSEEK_MODEL`. Depois de integrar `ia-gratis`, confira as novas variáveis na função daquele branch.

Com a Supabase CLI autenticada, publique a função no seu projeto:

```sh
supabase functions deploy ia-consultor --project-ref SEU_PROJECT_REF
```

Esses passos são instruções de implantação, não operações executadas pela documentação.

### Testes

```sh
flutter test
cd packages/cic_domain
dart pub get
dart test
```

Volte à raiz antes de executar os builds.

## Builds de produção

Web:

```sh
flutter build web --release --no-source-maps --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON_PUBLICA
```

Publique apenas `build/web` e confira a ausência de arquivos `.map`. CSP e demais headers são aplicados pela hospedagem, não pela compilação. Revise `vercel.json` depois de integrar a segurança.

Android:

```sh
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols/android --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON_PUBLICA
```

Para distribuição direta, use `flutter build apk` com os mesmos parâmetros. Configure assinatura de release e preserve os símbolos por versão em armazenamento privado.

O projeto também contém estrutura iOS. Compilar exige macOS, Xcode, assinatura e validação nessa plataforma:

```sh
flutter build ipa --release --obfuscate --split-debug-info=build/symbols/ios --dart-define=SUPABASE_URL=https://SEU-PROJETO.supabase.co --dart-define=SUPABASE_ANON_KEY=SUA_CHAVE_ANON_PUBLICA
```

## Arquitetura e diagramas

- [Índice e estado das integrações](docs/arquitetura/README.md)
- [Casos de uso do lojista](docs/arquitetura/casos-de-uso.md)
- [Componentes do aplicativo e backend](docs/arquitetura/componentes.md)
- [Sequência de uma pergunta ao assistente](docs/arquitetura/sequencia-assistente.md)
- [Classes do domínio e previsão de demanda](docs/arquitetura/classes-dominio.md)
- [Modelo de dados, chaves e RLS](docs/arquitetura/modelo-de-dados.md)

## Telas

As capturas serão adicionadas pelo responsável em `docs/prints/`, com dados de demonstração. Os links ficam preparados para os nomes combinados; até o envio, as imagens não estarão disponíveis.

### Início

![Visão inicial do APP-CIC](docs/prints/inicio.png)

### Vender

![PDV e registro de venda](docs/prints/vender.png)

### Leitor

![Leitor de código de barras GS1](docs/prints/leitor.png)

### Estoque

![Estoque e validade dos produtos](docs/prints/estoque.png)

### Assistente

![Assistente baseado nos dados da loja](docs/prints/assistente.png)

## Segurança e builds de publicação

O app contém somente a chave pública `anon` do Supabase. Chaves `service_role` e
de provedores de IA devem ficar em secrets no servidor, nunca em `--dart-define`
nem no código Flutter. O build da Vercel remove arquivos `.map` do artefato web.

Para aplicar o isolamento multi-loja, revise e execute
`supabase/seguranca_app_rls.sql` no SQL Editor do projeto Supabase. A migration
falha se encontrar uma tabela de negócio sem `empresa_id`, `user_id` ou
`owner_id` associado a `auth.uid()`.

Builds móveis de release usam obfuscação e geram símbolos separados:

```sh
bash tool/build_mobile.sh android
bash tool/build_mobile.sh ios
```

O build de iOS precisa rodar no macOS com Xcode. Guarde `build/symbols/` em local
privado e junto da versão publicada; os arquivos são necessários para decodificar
relatórios de falha e não devem ser distribuídos com o app.

No painel Supabase, mantenha a confirmação de e-mail habilitada em
Authentication / Providers / Email, configure senha mínima de 12 caracteres com
letras maiúsculas, minúsculas e números, e ajuste limites de envio/login em
Authentication / Rate Limits. O bloqueio no app é apenas uma camada de interface
e não substitui o limite do servidor.



