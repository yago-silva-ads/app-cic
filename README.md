# Projeto CIC 

Bem-vindo! 
Nosso aplicativo tem a função de ler o código de barras e auxiliá-lo a reconhecer o item através dos códigos GTIN-13 providos pela GS1.

Através do framework Flutter, traremos esta aplicação para o sistema Web e Android.

# Como iniciar a Aplicação

Neste período de desenvolvimento, o aplicativo pode ser acessado pelo framework Flutter, que possui um direcionamento multiplataforma.
Para abrir o projeto em seu dispositivo, é necessário que você possua os seguintes componentes:

- Flutter SDK
- Um editor de texto (recomendável ser o Visual Studio Code).
- Uma webcam para a leitura do código de barras.

### (Apenas para Android)
- Android SDK
- Aparelho Android ou um emulador Android compatível

Ao abrir o projeto no editor de texto, para iniciar a aplicação, você pode se direcionar para a pasta "lib" e abrir o arquivo "main.dart".

Para instalar as dependências do projeto em sua máquina, é necessário escrever o comando "flutter pub get" em seu terminal.

Após isto, você poderá pressionar o botão "F5" ou escrever "flutter run" para iniciar a aplicação.

Lá, você poderá rodar o arquivo e selecionar o navegador/dispositivo de sua preferência, seja Microsoft Edge, Google Chrome (...).

# Como usar a Aplicação

O programa consegue armazenar produtos de acordo com os códigos que forem lidos e guardá-los no estoque da loja. Ao abrir o aplicativo, a câmera/webcam iniciará automaticamente
e, assim que capturado um código, constará logo abaixo como "código lido" e a câmera terá seu uso encerrado até que seja clicado no botão "limpar câmera", para que outro código
de barras/QR seja lido. 

Ao cadastrar um produto, ele registra o código lido e o usuário pode incluir o número do lote, seu preço de custo e markup, assim o preço de venda será automaticamente sugerido 
pelo app. Caso seja cadastrado um código que já tenha sido registrado anteriormente, as novas informações sobreporão o do produto atual, evitando duplicidade. 

## Estoque Atual

Nesta aba, estarão presentes todos os produtos cadastrados no estoque do lojista.
Todas as informações, exceto a sugestão de venda e o código vinculado, são editáveis através da aba "Estoque Atual". O usuário também consegue excluir os produtos cadastrados ao 
arrastar o item para a esquerda.

## Dashboard Inteligente

O dashboard analisa as informações dos produtos cadastrados no estoque atual e faz uma análise, mostrando a soma do valor de custo e do retorno planejado. Graças a Inteligência 
Artificial, também é possível analisar o produto com maior retorno por unidade registrado e ele retorna um exame informando sobre dados do produto que merecem atenção, se houver
um baixo número de itens no estoque, seu potencial de venda comparado com o custo, entre outras informações relevantes sobre o inventário cadastrado.

## Custos Operacionais

O intuito desta página é que o usuário registre os custos fixos operacionais de seu estabelecimento, tendo a opção de rotulá-los e somá-los.



