# Como Adicionar Telas

Se o projeto evoluir e você precisar adicionar uma nova aba, siga estes passos para manter a arquitetura SPA:

1. **Crie a tela**: Em `lib/screens/`, crie seu arquivo. Exemplo: `tela_configuracoes.dart`.
2. **Ajuste o Scaffold**: Sua tela **não** deve retornar um `Scaffold` com `appBar` ou `drawer`. Ela deve retornar o miolo, como um `SingleChildScrollView` ou um `Container`. 
   > A `AppBar` centralizada fica no `main_layout.dart` em celulares, e os menus ficam ocultos em web/desktop.
3. **Adicione a tela no MainLayout**:
   Vá até `lib/screens/main_layout.dart`. No método `_buildConteudoPagina()`, adicione sua tela ao `switch(AppState.pageIndexNotifier.value)` ou na estrutura condicional do corpo.
4. **Adicione o botão no Menu**:
   Vá até `lib/widgets/app_drawer.dart`. Adicione um novo `ListTile` apontando para o seu índice novo usando `AppState.setPage(NOVO_INDICE)`.
