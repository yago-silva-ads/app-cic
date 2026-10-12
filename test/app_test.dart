import 'package:app_cic/core/format.dart';
import 'package:app_cic/core/gs1.dart';
import 'package:app_cic/core/nfe_parser.dart';
import 'package:app_cic/core/pix.dart';
import 'package:app_cic/core/theme.dart';
import 'package:app_cic/data/models.dart';
import 'package:app_cic/data/repository.dart';
import 'package:app_cic/services/ia_consultor.dart';
import 'package:app_cic/state/app_state.dart';
import 'package:cic_domain/cic_domain.dart' as dom;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AppState _estado() {
  final cli = SupabaseClient('https://exemplo.supabase.co', 'anon');
  return AppState(repo: CicRepository(cli), tema: TemaController())..carregouUmaVez = true;
}

Produto _p(String cod, String nome, int qtd, double custo, double venda, {DateTime? validade}) => Produto(
  codigo: cod,
  nome: nome,
  quantidade: qtd,
  valorCompra: custo,
  markup: venda / custo,
  valorVenda: venda,
  dataValidade: validade,
);

void main() {
  group('PIX (mesmo resultado do algoritmo do AI Studio)', () {
    test('payload com valor', () {
      expect(
        gerarPayloadPix(chave: '48912345000178', nomeRecebedor: 'Mercadinho CIC Ltda', cidadeRecebedor: 'Sao Paulo', valor: 41.5, identificador: 'CIC123456'),
        '00020126360014br.gov.bcb.pix011448912345000178520400005303986540541.505802BR5919Mercadinho CIC Ltda6009Sao Paulo62130509CIC1234566304BD4A',
      );
    });
    test('normaliza acentos', () {
      expect(
        gerarPayloadPix(chave: 'contato@loja.com.br', nomeRecebedor: 'José da Conceição', cidadeRecebedor: 'São Paulo', valor: 1, identificador: 'TESTE'),
        '00020126410014br.gov.bcb.pix0119contato@loja.com.br52040000530398654041.005802BR5917Jose da Conceicao6009Sao Paulo62090505TESTE6304B843',
      );
    });
  });

  group('GTIN', () {
    test('valida dígito verificador', () {
      expect(gtinValido('7891000100103'), isTrue);
      expect(gtinValido('4006381333931'), isTrue);
      expect(gtinValido('7891000100104'), isFalse);
      expect(gtinValido('12345'), isFalse);
      expect(gtinValido('78910001001O3'), isFalse);
    });
  });

  group('reconhecimento GS1', () {
    test('catálogo embutido reconhece sem internet e sem inventar custo', () async {
      final r = await consultarGs1('7894900010015');
      expect(r.encontrado, isTrue);
      expect(r.nome, contains('Coca-Cola'));
      expect(r.origem, 'Catálogo GS1 Brasil');
    });
  });

  group('formatação', () {
    test('lerDecimal aceita formatos brasileiros', () {
      expect(lerDecimal('12,50'), 12.5);
      expect(lerDecimal('1.234,56'), 1234.56);
      expect(lerDecimal('R\$ 7'), 7);
      expect(lerDecimal('abc'), isNull);
    });
    test('centavos sem erro de ponto flutuante', () {
      expect(centavos(19.99), 1999);
      expect(centavos(0.1 + 0.2), 30);
    });
  });

  group('NF-e', () {
    const xml = '<?xml version="1.0"?>'
        '<nfeProc xmlns="http://www.portalfiscal.inf.br/nfe"><NFe><infNFe Id="NFe35260902838472000184550010000492101928472910">'
        '<ide><natOp>VENDA</natOp><serie>1</serie><nNF>49210</nNF><dhEmi>2026-09-18T08:30:00-03:00</dhEmi></ide>'
        '<emit><CNPJ>02838472000184</CNPJ><xNome>AMBEV SA</xNome><xFant>AMBEV</xFant></emit>'
        '<det nItem="1"><prod><cProd>B1</cProd><cEAN>7891000100103</cEAN><xProd>Leite Condensado</xProd><uCom>UN</uCom><qCom>10.0000</qCom><vUnCom>5.9000</vUnCom><vProd>59.00</vProd></prod><rastro><nLote>L1</nLote><dVal>2027-01-20</dVal></rastro></det>'
        '<det nItem="2"><prod><cProd>B2</cProd><cEAN>SEM GTIN</cEAN><xProd>Granel</xProd><uCom>KG</uCom><qCom>2.5000</qCom><vUnCom>8.0000</vUnCom><vProd>20.00</vProd></prod></det>'
        '<total><ICMSTot><vNF>79.00</vNF></ICMSTot></total></infNFe></NFe></nfeProc>';

    test('interpreta chave, itens e rastro sem inventar dados', () {
      final n = interpretarNfe(xml);
      expect(n.chave, '35260902838472000184550010000492101928472910');
      expect(n.numero, '49210');
      expect(n.itens, hasLength(2));
      expect(n.itens[0].codigoBarras, '7891000100103');
      expect(n.itens[0].validade, DateTime(2027, 1, 20));
      expect(n.itens[0].avisos, isEmpty);
      expect(n.valorTotal, 79);
    });
    test('sem GTIN e quantidade fracionada geram avisos', () {
      final i = interpretarNfe(xml).itens[1];
      expect(i.semGtin, isTrue);
      expect(i.codigoBarras, 'B2');
      expect(i.quantidadeInteira, isFalse);
      expect(i.avisos.length, greaterThanOrEqualTo(2));
    });
    test('XML inválido e sem itens viram erro claro', () {
      expect(() => interpretarNfe('<a><b></a>'), throwsA(isA<ErroNfe>()));
      expect(() => interpretarNfe('<nfe></nfe>'), throwsA(isA<ErroNfe>()));
    });
  });

  group('estado + domínio', () {
    test('saldo vem da coluna quantidade (nunca quantidade - vendidas)', () {
      final e = _estado()..estoque = [_p('1', 'A', 7, 2, 4)];
      e.estoque.first.vendidas = 100; // não pode influenciar o saldo
      final resumo = const dom.EstoqueService().resumir(e.snapshot());
      expect(resumo.unidadesDisponiveis, 7);
      expect(resumo.produtosComSaldo, 1);
    });

    test('falha ao carregar o estoque = saldo desconhecido, não zero', () {
      final e = _estado()..estoque = [_p('1', 'A', 7, 2, 4)];
      e.erros['estoque'] = 'falhou';
      final snap = e.snapshot();
      expect(snap.carregado, isFalse);
      expect(const dom.EstoqueService().resumir(snap).completo, isFalse);
    });

    test('Curva ABC realizada usa custo e preço históricos da venda', () {
      final e = _estado()
        ..estoque = [_p('1', 'Cerveja', 5, 2, 4), _p('2', 'Agua', 50, 1, 2)]
        ..vendas = [
          VendaItemHistorico(id: 'a', vendaId: 'v1', produtoCodigo: '1', nomeProduto: 'Cerveja', quantidade: 10, valorUnitario: 5, custoUnitario: 2, data: DateTime.now()),
          VendaItemHistorico(id: 'b', vendaId: 'v1', produtoCodigo: '2', nomeProduto: 'Agua', quantidade: 1, valorUnitario: 2, custoUnitario: 1, data: DateTime.now()),
        ];
      final r = e.curvaAbc(dom.PeriodoAbc.todos);
      expect(r.itens.first.nome, 'Cerveja');
      expect(r.itens.first.valorBaseCentavos, 5000);
      expect(r.itens.first.lucroBrutoCentavos, 3000); // preço histórico 5, não o atual 4
      expect(r.itens.first.classe, dom.ClasseAbc.A);
      expect(r.alertas.single.produtoId, '1'); // classe A com 5 un
    });

    test('desconto da venda é rateado como desconto de pedido', () {
      final e = _estado()
        ..estoque = [_p('1', 'A', 5, 1, 2)]
        ..vendas = [VendaItemHistorico(id: 'a', vendaId: 'v', produtoCodigo: '1', quantidade: 10, valorUnitario: 10, custoUnitario: 4, data: DateTime.now(), desconto: 10)];
      final r = e.curvaAbc(dom.PeriodoAbc.todos);
      expect(r.itens.single.valorBaseCentavos, 9000);
    });
  });

  group('consultor (sem IA)', () {
    test('estoque, faturamento e mais vendido saem do cálculo', () async {
      final e = _estado()
        ..estoque = [_p('1', 'Cerveja', 5, 2, 4), _p('2', 'Agua', 0, 1, 2)]
        ..vendas = [VendaItemHistorico(id: 'a', vendaId: 'v1', produtoCodigo: '1', nomeProduto: 'Cerveja', quantidade: 3, valorUnitario: 5, custoUnitario: 2, data: DateTime.now())];
      final ia = IaConsultor(e);
      final est = await ia.perguntar('O que tenho no meu estoque agora?');
      expect(est!.origem, dom.OrigemResposta.deterministica);
      expect(est.resposta, contains('1 produto com saldo'));
      expect(est.resposta, contains('5 unidades disponíveis'));
      expect(est.resposta, contains('2 cadastrados'));

      final fat = await ia.perguntar('Quanto faturei nos últimos 30 dias?');
      expect(fat!.resposta, contains('R\$ 15,00'));

      final top = await ia.perguntar('Qual o produto mais vendido?');
      expect(top!.resposta, contains('Cerveja'));
    });

    test('estoque não carregado: não inventa números', () async {
      final e = _estado()..erros['estoque'] = 'x';
      final r = await IaConsultor(e).perguntar('o que tenho no estoque?');
      expect(r!.tipo, dom.TipoResposta.indisponivel);
      expect(r.resposta, isNot(contains('R\$')));
    });

    test('pergunta por produto específico responde o saldo real', () async {
      final e = _estado()..estoque = [_p('789', 'Leite UHT Integral', 12, 3, 5), _p('790', 'Cerveja Lata', 0, 2, 4)];
      final ia = IaConsultor(e);
      final leite = await ia.perguntar('Tem leite?');
      expect(leite!.resposta, contains('Sim, você tem'));
      expect(leite.resposta, contains('12 un em estoque'));
      final cerveja = await ia.perguntar('quanto tem de cerveja?');
      expect(cerveja!.resposta, contains('SEM ESTOQUE'));
      final nada = await ia.perguntar('tem picanha?');
      expect(nada!.resposta, contains('Não encontrei'));
      expect(nada.resposta, isNot(contains('Sim')));
      final falta = await ia.perguntar('o que está em falta?');
      expect(falta!.resposta, contains('Cerveja Lata'));
      expect(falta.resposta, isNot(contains('Leite')));
    });

    test('perguntas seguidas no mesmo chat: cada uma recebe a sua resposta', () async {
      final e = _estado()..estoque = [_p('789', 'Leite UHT', 12, 3, 5), _p('790', 'Cerveja Lata', 0, 2, 4)];
      final ia = IaConsultor(e);
      final perguntas = ['Tem leite?', 'o que está em falta?', 'O que tenho no meu estoque agora?', 'tem cerveja?'];
      for (final p in perguntas) {
        final r = await ia.perguntar(p);
        expect(r, isNotNull, reason: p);
      }
      expect((await ia.perguntar('tem cerveja?'))!.resposta, contains('SEM ESTOQUE'));
      expect((await ia.perguntar('Tem leite?'))!.resposta, contains('12 un'));
    });

    test('perguntas gerais não viram busca de produto', () async {
      final e = _estado()..estoque = [_p('1', 'Cola', 1, 1, 1.1)];
      final r = await IaConsultor(e).perguntar('Quais produtos têm markup abaixo de 1,30x?');
      expect(r!.resposta, contains('markup abaixo de 1,30x'));
    });

    test('produtos acabando lista só o que está no mínimo', () async {
      final e = _estado()..estoque = [_p('1', 'Cola', 2, 1, 2), _p('2', 'Suco', 90, 1, 2)];
      final r = await IaConsultor(e).perguntar('quais produtos estão acabando?');
      expect(r!.resposta, contains('Cola'));
      expect(r.resposta, isNot(contains('Suco')));
    });
  });

  test('auditoria é determinística e usa só dados reais', () {
    final e = _estado()
      ..estoque = [_p('1', 'Cola', 2, 10, 12)]
      ..custos = [CustoOperacional(nome: 'Aluguel', valor: 1000)];
    final t = montarAuditoria(e);
    expect(t, contains('ALERTA'));
    expect(t, contains('R\$ 1.000,00'));
  });
}
