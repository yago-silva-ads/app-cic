# Do convite à loja ativa e à proposta de site

O app é gratuito durante as quatro semanas do teste de campo, sem cartão. A criação de site é um serviço pago separado. Só negociar assinatura futura do app depois de medir a utilidade e apresentar condições claras. O piloto não exige comprar o site.

## Etapas e responsáveis

| Etapa | Entrega verificável | Responsável |
|---|---|---|
| Selecionar | Pequeno comércio compatível com caixa e estoque; excluir quem pediu para sair | LeadForge + revisão de Yago |
| Convidar | Link `/t/<slug>/` preparado; mensagem revisada e envio registrado | Yago, pelo fluxo existente |
| Cadastrar | Conta com `origem=leadforge` e `convite=<slug>` | Lojista |
| Ativar | Três produtos distintos, Pix cadastrado e primeira venda | Lojista com treinamento |
| Acompanhar | Uso real e feedback da semana; dificuldade recebe atendimento | Yago |
| Oferecer site | Interesse explícito, demonstração e proposta com escopo/preço | Yago + LeadForge |
| Encerrar quatro semanas | Entrevista curta, resultado medido e decisão sobre continuidade | Yago + lojista |

Conta criada não prova uso. Pix cadastrado não prova pagamento. Venda registrada não prova liquidação bancária. Site gerado não é venda fechada. Mantenha essas etapas separadas no acompanhamento.

## Fila de acompanhamento sem disparos

1. No SQL Editor administrativo, execute [relatorio_piloto_leadforge.sql](../supabase/relatorio_piloto_leadforge.sql), que é somente de leitura. Não dê acesso administrativo ao app nem publique credenciais.
2. Exporte o resultado como CSV para uma pasta privada, fora do repositório.
3. Execute `python tool/planejar_piloto.py caminho/do/relatorio.csv`. O resultado é uma fila CSV no terminal: prioridade, slug e próxima ação. Nenhuma mensagem é enviada.
4. Antes de contatar, confira no LeadForge o histórico, a preferência de contato e eventuais pedidos de saída. O relatório do app não substitui esse controle.
5. Resolva notas baixas primeiro. Apresente site quando houver `quero_conhecer` ou `quero_orcamento`. Sem interesse registrado, priorize ativação e aprendizado do piloto.

O relatório usa contagens por loja antes dos joins, para não multiplicar produtos ou vendas; agrupa linhas de uma mesma venda pelo `venda_id`. A semana do relatório começa na segunda-feira em São Paulo. O app usa o calendário local do aparelho: verifique a data se o participante estiver em outro fuso. Slugs são atribuição comercial, não autorização nem identidade comprovada.

Vendas antigas sem `venda_id` são contadas por linha do histórico, não como cupons comprovadamente distintos. Duas contas podem declarar o mesmo slug; confira duplicidades antes de interpretar as linhas como lojas únicas.

Não há sincronização automática desse relatório com o CRM nem disparo de WhatsApp implementado nesta etapa. Não publique o CSV. Falta validar a consulta no banco real; até lá, não trate a saída como métrica confirmada. O campo Pix não entra no relatório para evitar acessar dados cifrados.

## Rotina de quatro semanas

- Dia 0: convite e orientação para começar. Mostrar leitor, estoque e caixa; confirmar a primeira tarefa que o comerciante quer resolver.
- Dias 1–3: ajudar nas dificuldades de cadastro ou primeira venda. Registrar problema, dispositivo e reprodução, sem pedir senha.
- Semanas 1–3: revisar uso e feedback; oferecer um vídeo curto da tarefa que estiver travando. O lembrete dentro do app vem antes de insistir por mensagem.
- Semana 4: perguntar o que economizou tempo, que erros evitou e o que falta para uso diário. Medir lojas ativadas, lojas com vendas nos últimos sete dias, feedback recebido e interesse espontâneo em site.

Para vender o site: “Além do teste gratuito do app, preparo sites para divulgar a loja. Você quer ver uma demonstração e os valores?” Depois do interesse, definir páginas, WhatsApp, domínio, manutenção, preço e prazo. O status **FECHADO** no LeadForge deve acompanhar pagamento confirmado pela rotina já existente, não apenas o clique na proposta.

## Ordem das melhorias do app

1. Corrigir perda de dados, isolamento entre lojas e duplicação de venda antes de recursos novos.
2. Validar com uma conta de teste: cadastro por convite → três produtos → venda → estoque → pergunta à IA → feedback. Guardar resultados, sem dados pessoais.
3. Priorizar cada melhoria por frequência do problema, impacto no caixa e esforço estimado. Uma sugestão isolada não deve desorganizar o piloto.
4. Depois da evidência de uso, avaliar fiado, funcionários, operação offline, pagamento integrado e emissão fiscal com requisitos próprios.

Os vídeos atuais não devem prometer pagamento automático, NFC-e ou integração oficial com a base GS1. Antes de distribuir, revisar o APK e cada módulo gravado.
