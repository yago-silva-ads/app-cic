# Como Testar Multiplataforma

O aplicativo foi projetado para rodar em Web (Desktop/Celular), Android e iOS.
Aqui está como testá-los:

## Para Navegador Web (Chrome)
1. No VSCode (ou terminal), digite:
   `flutter run -d chrome`
2. **Testando responsividade**: Ao abrir a tela, diminua a janela do Chrome para a largura de um celular. Você verá o painel lateral sumir e se transformar em um botão *hamburguer* elegante.

## Para Celular Real (Android/iPhone)
1. Baixe o aplicativo "Flutter" no seu celular ou conecte-o via cabo USB.
2. Com o celular detectado, rode `flutter run -d [id-do-dispositivo]`.
3. Todo o layout de tabelas de estoque e os gráficos luxuosos do dashboard agora possuem `SingleChildScrollView(scrollDirection: Axis.horizontal)`. Se os dados espremerem a tela, **arraste para o lado com o dedo**.

## Erros Frequentes
- **RenderFlex Overflow**: Típica barra amarela listrada de erro. Ocorre quando as caixas estouram o limite da tela pequena. A solução sempre é colocar a área em um `Expanded`, `Flexible` ou `SingleChildScrollView`. Nunca limite a largura usando pixels duros (`width: 600`). Use percentuais (`MediaQuery.of(context).size.width * 0.8`).
