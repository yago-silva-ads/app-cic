# Diário de Decisões: SPA e Multiplataforma

*Data da migração: 17 de Setembro de 2026*

## O Problema Inicial
No início, o aplicativo utilizava a navegação padrão por pilha (`Navigator.push`), onde ao clicar num menu (Drawer), o sistema destruía a tela anterior e construía uma nova do zero.

**Problemas causados:**
1. A cada transição, a tela engasgava, os dados do Supabase eram recarregados de forma duplicada (gerando custos no banco e lentidão visual).
2. Não havia distinção elegante de menu entre celular e computador. Em computadores largos, um menu flutuante e minúsculo não passava a credibilidade de um "SaaS Premium".

## A Decisão: Single Page Application (SPA)
Em vez de movermos telas pela pilha, montamos o **`main_layout.dart`**. 
- Ele exibe uma **Sidebar** fixa se a largura for maior que 800px. Se for menor, ele esconde a sidebar e aciona o **Hamburger Button**.
- Usamos `IndexedStack`. Isso quer dizer que "Estoque", "IA", e "Dashboard" são carregadas uma vez e ficam escondidas. Quando você troca, a tela altera o índice (usando o leve `ValueNotifier` de `app_state.dart`) instantaneamente. Sem telas de loading.

## Blindagem Anti-Crash
O `supabase_helper.dart` foi modificado para utilizar extensivos blocos `try/catch`. 
Se o desenvolvedor se esquecer de aplicar as RLS (Row Level Security) e a requisição tomar um 'Acesso Negado', o sistema continuará operante, apenas sinalizando o erro nos terminais em vez de uma tela de morte (Telas de Crash Vermelhas). O mesmo para gráficos longos no celular, que agora usam scroll horizontal.
