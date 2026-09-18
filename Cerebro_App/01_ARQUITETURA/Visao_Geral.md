# Visão Geral da Arquitetura

O aplicativo CIC é estruturado como um **Single Page Application (SPA)** robusto, permitindo alta fluidez, semelhante aos melhores SaaS do Vale do Silício.

## O Layout Principal
A âncora do aplicativo é o arquivo `lib/screens/main_layout.dart`. Em vez de navegar usando `Navigator.push` (o que destrói as abas antigas e recarrega dados repetidamente), nós utilizamos um `IndexedStack`.
Isso significa que todas as 5 abas principais do aplicativo ficam em memória. Quando o usuário troca do Estoque para a Inteligência Artificial, a troca leva **milissegundos** e não exige recarregamento.

## Gerenciamento de Estado Global
O estado que diz qual aba está aberta reside no arquivo `lib/services/app_state.dart`. 
Usamos `ValueNotifier<int> pageIndexNotifier`, que é extremamente leve e reativo.

## Telas (Filhas)
As telas em si (`tela_estoque.dart`, `leitor_screen.dart`) não possuem mais o seu próprio `Scaffold` completo. Elas se comportam como *widgets limpos*, inserindo seu conteúdo dentro do Scaffold mestre (`main_layout`).
