# Visão Geral da Arquitetura

O aplicativo **CIC (Controle de Estoque Inteligente)** utiliza uma arquitetura *Single Page Application (SPA)*.

## Tecnologias Principais
- **Frontend:** Flutter
- **Backend:** Supabase
- **Padrão de Navegação:** Layout Central (`MainLayout`) com troca de componentes filhos, eliminando o uso de `Navigator.push()` para a navegação primária.

## Estrutura do Projeto
- `lib/screens/main_layout.dart`: Gerencia o Layout base, menu lateral/inferior e o componente atualmente ativo.
- `lib/screens/`: Contém os componentes principais (Dashboard, Leitor, Estoque) que são renderizados no MainLayout.
- `lib/models/`: Classes de dados.
- `lib/services/`: Integração com APIs externas (Supabase, OpenAI, etc).
