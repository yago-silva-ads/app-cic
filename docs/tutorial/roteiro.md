# Roteiro de treinamento — APP-CIC

Este vídeo apresenta o APP-CIC para o dono de um mercadinho. Fale com calma, mostre cada tela e use a loja de demonstração quando estiver treinando pela primeira vez.

Na gravação automática com `DEMO=true`, os dados são exemplos. O aviso de feedback no início e o checklist de loja nova ficam ocultos. O módulo de feedback abre o formulário por **Inteligência IA** e cancela sem enviar. O módulo de primeiros passos é explicativo; para mostrar o cartão funcionando, grave uma tomada complementar com uma conta de teste nova, sem DEMO e sem dados de clientes. A pesquisa de mercado abre a seleção do produto e cancela, sem consultar ofertas pela rede. A demonstração do PDV explica o Pix, mas não simula recebimento bancário.

Os rótulos abaixo foram conferidos no código das telas. A localização por papel acessível no Playwright ainda precisa de ensaio no navegador. Não clicar em botões ocultos nem narrar uma operação como concluída quando ela apenas foi explicada.

Nota para quem grava: `gravar.py` foi recuperado do checkout `codex-app-cic-docs-seguranca`, mantendo os helpers originais. Para executar, mantenha ao lado o `montagem.py` do mesmo conjunto de ferramentas e as dependências de gravação já usadas. Esta atualização não executa a gravação nem gera os vídeos.

## 1. Visão Geral

### CENA

1. No menu lateral, clique em **Visão Geral**.
2. Mostre os cartões de estoque, faturamento, custos e resultado projetado.
3. Na seção **Curva ABC de Estoque (Pareto 80/20)**, clique em **Hoje**, **7 dias**, **30 dias**, **Todo o período** ou **Estoque atual (projetado)**, conforme a comparação que deseja mostrar.
4. Se aparecer o aviso de prejuízo, clique em **Consultar IA**.
5. No cartão do consultor, clique em **Abrir Diagnóstico com IA**.

### NARRAÇÃO

Esta é a Visão Geral da sua loja.
Aqui você acompanha o estoque, as vendas e os custos em poucos segundos.
A Curva ABC mostra quais produtos merecem mais atenção.
Use os períodos para comparar o movimento de hoje, da semana ou do mês.
Quando aparecer um alerta de risco, abra o diagnóstico para entender a situação.

## 2. Leitor de códigos e cadastro

### CENA

1. No menu, clique em **Leitor de códigos**.
2. Clique em **Abrir câmera / bipador** e autorize a câmera, se o aparelho pedir.
3. Aponte para o código de barras e aguarde a leitura; se preferir, digite o código e clique em **Consultar**.
4. Preencha nome, lote, custo, preço, tipo do produto e validade.
5. Para uma entrada de inventário existente, marque **Substituir o saldo (contagem de inventário)** quando for necessário.
6. Clique em **Salvar no estoque**.
7. Para começar outra leitura, clique em **Limpar**.

### NARRAÇÃO

O Leitor de códigos ajuda a cadastrar os produtos pelo código de barras.
Aponte a câmera para o produto ou digite o código manualmente.
Informe o lote, a validade, o custo e o preço de venda.
Se você estiver contando o estoque, escolha substituir o saldo atual.
Depois de conferir os dados, clique em salvar no estoque.
O produto ficará disponível para venda e acompanhamento.

## 3. Importador XML

### CENA

1. No menu, clique em **Importador XML (NF-e)**.
2. Clique em **Carregar arquivo .XML** e selecione o arquivo da nota.
3. Se recebeu o texto por outro meio, clique em **Colar texto XML**, cole o conteúdo e clique em **Processar XML colado**.
4. Confira os itens, lote, validade e o **Markup padrão**.
5. Marque ou desmarque **Atualizar também o preço de venda dos produtos que já existem** conforme sua decisão.
6. Use **Marcar todos** ou **Desmarcar** para ajustar a seleção.
7. Confirme a entrada e clique em **Ver no estoque**.

### NARRAÇÃO

O Importador XML ajuda a lançar uma nota de compra sem digitar produto por produto.
Carregue o arquivo da NF-e ou cole o texto recebido.
Confira os itens, os custos, os lotes e as datas de validade.
Decida se os preços de venda existentes devem ser atualizados.
Selecione apenas o que deseja lançar e confirme a entrada.
Importar a mesma nota novamente não deve duplicar o estoque.

## 4. Estoque Atual

### CENA

1. No menu, clique em **Estoque Atual**.
2. Clique em **Importar NF-e (XML)** para voltar ao importador, ou em **Cadastrar Produto** para abrir o cadastro pelo leitor.
3. Na lista, localize um produto pelo nome ou código e abra o cartão do produto.
4. No formulário, ajuste os campos necessários e clique em **Salvar Alterações**.
5. Se desistir da edição, clique em **Cancelar**.
6. Mostre a quantidade, o lote, a validade, o custo, o preço e o aviso de estoque baixo.

### NARRAÇÃO

Esta tela é a visão completa do seu inventário.
Você pode conferir saldo, validade, lote, custo e preço de cada produto.
Use o cadastro pelo leitor ou importe uma nova nota quando precisar.
Para corrigir um item, abra o produto, faça a alteração e salve.
O saldo atual é o que o sistema considera disponível para vender.
Mantenha o estoque mínimo bem ajustado para receber alertas úteis.

## 5. Histórico & Movimentações

### CENA

1. No menu, clique em **Histórico & Movimentações**.
2. Clique em **Registrar Movimentação Manual**.
3. Escolha o tipo de entrada ou saída, o motivo e o produto em **Selecione o produto...**.
4. Informe a quantidade e os detalhes solicitados.
5. Clique em **Registrar**; para sair sem salvar, clique em **Cancelar**.
6. Use o filtro **Filtrar por periodicidade:** para revisar um período.

### NARRAÇÃO

O Histórico mostra o caminho do seu estoque.
Aqui você confere compras, vendas, entradas, perdas e ajustes.
Uma entrada manual serve para registrar uma correção ou recebimento que não veio por XML.
Escolha sempre o motivo correto para manter a história organizada.
Depois de registrar, a movimentação aparece junto com a data e o documento.
Use o filtro de período para investigar uma semana ou um mês específico.

## 6. Inteligência IA

### CENA

1. No menu, clique em **Inteligência IA**.
2. Clique em **Executar Auditoria Completa** e aguarde o diagnóstico.
3. Clique em **Salvos (0)**, ou no botão com a quantidade atual, para abrir o histórico de relatórios.
4. Abra um relatório e clique em **Copiar** para levar o texto para outro lugar.
5. Clique em **Recolher** para fechar o relatório.
6. Na conversa, escreva uma pergunta em **Pergunte sobre o seu negócio...** e clique em **Enviar**.
7. Para começar a conversa novamente, use o ícone com a dica **Limpar conversa**.

### NARRAÇÃO

A Inteligência IA transforma os dados da loja em orientação prática.
Comece pela Auditoria Completa para receber um diagnóstico do estoque, das vendas e dos custos.
Os números são calculados pelo sistema antes da explicação da inteligência artificial.
Você também pode perguntar sobre estoque, faturamento, validade, margem e Curva ABC.
Se a inteligência estiver indisponível, o aplicativo mostra os dados calculados com segurança.
Salve ou copie os relatórios para conversar com sua equipe.

## 7. Custos & Despesas

### CENA

1. No menu, clique em **Custos & Despesas**.
2. Em **CLASSIFICAÇÃO DA DESPESA**, escolha **Custo Fixo (Estrutura)** ou **Despesa Variável (Giro)**.
3. Preencha **Descrição da despesa** e **Valor médio mensal (R$)**.
4. Escolha a categoria em **CATEGORIA DA DESPESA** e, se necessário, preencha **Observação / detalhe**.
5. Clique em **Salvar Despesa**.
6. Para alterar um lançamento, abra-o, edite os campos e clique em **Atualizar Despesa**.
7. Durante a edição, clique em **Cancelar** para abandonar a alteração.

### NARRAÇÃO

Registre aqui os gastos que mantêm a loja funcionando.
Custo fixo é aquele que existe mesmo em um mês de poucas vendas, como aluguel e luz.
Despesa variável cresce conforme a operação, como taxa de cartão, sacola e frete.
Informe um valor médio mensal para o sistema estimar sua meta diária.
Uma lista bem preenchida ajuda a calcular o ponto de equilíbrio.
Revise os valores sempre que suas contas mudarem.

## 8. Central de Alertas

### CENA

1. No menu, clique em **Central de Alertas**.
2. Marque **Exibir somente não lidos** para ver apenas o que ainda precisa de atenção.
3. Abra um alerta de validade, estoque ou prejuízo para ler a mensagem.
4. Clique em **Ver no estoque** quando o alerta indicar um produto.
5. Depois de revisar tudo, clique em **Marcar todos como lidos**.

### NARRAÇÃO

A Central de Alertas funciona como uma lista de lembretes da loja.
Ela ajuda a perceber validade próxima, estoque baixo e risco de prejuízo.
Use o filtro para ver somente o que ainda está pendente.
Quando um alerta apontar um produto, abra o estoque diretamente por aqui.
Marque os alertas como lidos depois de tomar a providência.
Assim, a equipe sempre sabe o que precisa ser resolvido primeiro.

## 9. Frente de Caixa (PDV)

### CENA

1. No menu, clique em **Frente de Caixa (PDV)**.
2. Clique em **Bipar** ou toque em um produto da vitrine.
3. Confira os itens no **CARRINHO DE VENDA** e clique em **Ir p/ Pagamento**.
4. Em **Forma de pagamento:** escolha a opção usada pelo cliente.
5. Para Pix, cadastre antes a chave da loja em **Conta**, na seção **2. Conta & PIX**. Com itens no carrinho e chave cadastrada, use **Copiar PIX Copia e Cola**. Confira o crédito no aplicativo do banco e marque **Conferi no banco e recebi este PIX**. Copiar o código ou ver o comprovante do cliente não confirma o recebimento.
6. Para cartão, confirme na maquininha e clique em **Aprovado na máquina**.
7. Para dinheiro, informe o valor recebido e confira o troco.
8. Clique em **Finalizar venda e gerar comprovante**. Mostre o aviso **Comprovante não fiscal. O app não emite NFC-e.**
9. No comprovante, clique em **Copiar texto do cupom** ou em **Nova Venda (Frente de Caixa)**.

### NARRAÇÃO

O Frente de Caixa foi feito para uma venda rápida e organizada.
Bipe o produto ou toque nele na vitrine para colocá-lo no carrinho.
Confira quantidades e valores antes de ir para o pagamento.
Para Pix, cadastre a chave da loja, confira o crédito no banco e marque a confirmação de recebimento.
No dinheiro, confira o troco; no cartão, confirme a aprovação na maquininha.
Finalize para registrar a venda, baixar o estoque e gerar um comprovante não fiscal.
O app não emite cupom fiscal e a confirmação do Pix é manual.

## 10. Central do lojista — Ajuda & Suporte

### CENA

1. No menu, clique em **Ajuda & Suporte**.
2. Mostre **O que você pode fazer no app** e as orientações de estoque, vendas, notas e alertas.
3. Em **Respostas rápidas**, abra **Como começo?**.
4. Clique em **Copiar e-mail** para guardar o contato. **Enviar e-mail** abre seu aplicativo de e-mail.
5. Ao pedir ajuda, informe a tela em que estava e o que aconteceu.

### NARRAÇÃO

Ajuda e Suporte é a central do lojista.
Aqui você encontra orientações rápidas sobre as tarefas da loja.
Abra Como começo para rever os primeiros passos.
Se precisar de atendimento, copie o e-mail e conte o que aconteceu.
No menu, você também pode trocar o tema e aumentar a letra.

## 11. Logística reversa

### CENA

1. No menu, clique em **Logística reversa**.
2. Confira **PRODUTO**, **MOTIVO** e **DESTINO**. Exemplos de motivo: **Devolução ao fornecedor**, **Produto avariado**, **Produto vencido** e **Recall**.
3. Informe **Quantidade**, **Documento ou protocolo (opcional)** e **Observação (opcional)**.
4. Mostre **Registrar saída reversa**. No vídeo automático, apenas apresente o formulário. Para executar, use estoque de teste e confira antes de confirmar.
5. Após uma saída confirmada, confira o registro em **Histórico & Movimentações**.

### NARRAÇÃO

Precisa retirar uma mercadoria por avaria, vencimento, recall ou devolução ao fornecedor?
Escolha o produto, o motivo, o destino e a quantidade.
Se tiver, informe o documento ou protocolo.
Confira antes de registrar a saída reversa.
A saída reduz o estoque e fica no histórico. Ela não emite uma nota de devolução.

## 12. Pesquisa de mercado

### CENA

1. Abra **Inteligência IA** e localize **Análise de mercado e preço**.
2. Clique em **Analisar um produto**. No diálogo **Escolha o produto**, confira o item selecionado.
3. No vídeo automático, mostre a seleção e clique em **Cancelar**. Para uma tomada com consulta real, clique em **Consultar mercado** com conexão disponível e aguarde.
4. Havendo resultado, mostre a recomendação de aumentar, reduzir ou manter, o motivo e **Fontes consultadas**. Dados insuficientes podem exigir revisão, em vez de recomendar um novo preço.
5. Explique o piso de margem; não prometa aumento de lucro ou alteração automática do cadastro.

### NARRAÇÃO

Toque em Analisar um produto e escolha o item.
Com conexão, use Consultar mercado para buscar ofertas públicas.
O app pode sugerir aumentar, reduzir ou manter o preço, respeitando o custo e o piso de margem.
Se faltarem dados, ele pode pedir uma revisão.
Confira as fontes e decida. A sugestão não muda o cadastro sozinha.

## 13. Feedback semanal do teste de campo

### CENA

1. Na conta real, entre em **Visão Geral**. Se ainda não respondeu à semana atual, o cartão **Seu feedback desta semana** oferece **Responder formulário**. A semana começa na segunda-feira.
2. Na DEMO, esse aviso fica oculto. Abra **Inteligência IA** e clique em **Responder feedback semanal**, que abre o formulário existente nessa tela.
3. No diálogo **Feedback semanal do teste de campo**, mostre a nota de 1 a 5, **O que mais ajudou?**, **O que devemos melhorar?** e **Você recomendaria o app?**.
4. Na gravação automática, clique em **Cancelar**, sem enviar dados de treinamento. Em uso real, escolha uma nota e toque em **Enviar feedback**.
5. Depois de enviado, o aviso no início desaparece na próxima consulta. Em Inteligência IA, o botão passa a indicar **Feedback desta semana enviado** e fica desabilitado até a próxima semana ser consultada.

### NARRAÇÃO

No teste de campo, conte toda semana como foi usar o app.
Na sua conta, o início lembra quando a resposta está pendente.
Nesta demonstração, abrimos o formulário pela Inteligência IA.
Dê uma nota, marque o que ajudou e escreva o que precisa melhorar.
São cerca de dois minutos para orientar as próximas melhorias.

## 14. Primeiros passos da loja

### CENA

1. A tomada automática mostra **Visão Geral** com explicação narrada: o checklist fica oculto em `DEMO=true`.
2. Para a tomada complementar, entre com uma conta de teste nova, sem DEMO, e aguarde o carregamento dos dados. Mostre **Primeiros passos da sua loja**.
3. Toque em **Cadastrar a chave Pix da loja** para abrir a conta e informar a chave.
4. Toque em **Cadastrar 3 produtos** para abrir **Leitor de códigos**. São três produtos distintos, não três unidades do mesmo produto.
5. Toque em **Fazer a primeira venda** para abrir **Frente de Caixa (PDV)**. Use apenas dados de teste na gravação.
6. Volte à **Visão Geral** para mostrar os itens marcados como **Feito** a partir dos dados salvos. O cartão desaparece quando os três passos estão concluídos.

### NARRAÇÃO

Ao entrar com uma loja nova, o início mostra um checklist de preparação.
Cadastre a chave Pix, três produtos e faça a primeira venda.
Toque no passo pendente para abrir a área correspondente.
As marcas vêm dos dados da loja. Ao concluir os três passos, o cartão desaparece.
O checklist não aparece nesta loja de demonstração. Use sua conta para acompanhar o progresso.
