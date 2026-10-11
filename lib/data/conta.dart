/// Conta do estabelecimento e sessão de caixa (porte de `ContaEstabelecimento`
/// e `SessaoCaixa` do `types.ts`). Persistidas no Supabase, por loja.
library;

double _n(dynamic v, [double p = 0]) => v is num ? v.toDouble() : (double.tryParse('$v') ?? p);
String _s(dynamic v, [String p = '']) => v == null ? p : '$v';

class Maquininha {
  Maquininha({
    required this.id,
    required this.nome,
    this.provedor = 'OUTRA',
    this.taxaDebito = 0,
    this.taxaCredito = 0,
    this.prazoDias = 1,
  });

  final String id;
  String nome;
  String provedor;
  double taxaDebito;
  double taxaCredito;
  int prazoDias;

  factory Maquininha.fromJson(Map<String, dynamic> j) => Maquininha(
    id: _s(j['id'], 'maq-${DateTime.now().microsecondsSinceEpoch}'),
    nome: _s(j['nome']),
    provedor: _s(j['modeloProvedor'], 'OUTRA'),
    taxaDebito: _n(j['taxaDebito']),
    taxaCredito: _n(j['taxaCredito']),
    prazoDias: _n(j['prazoRecebimentoDias'], 1).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nome': nome,
    'modeloProvedor': provedor,
    'taxaDebito': taxaDebito,
    'taxaCredito': taxaCredito,
    'prazoRecebimentoDias': prazoDias,
    'status': 'CONECTADA',
  };
}

class ContaEstabelecimento {
  ContaEstabelecimento({
    this.nomeFantasia = '',
    this.razaoSocial = '',
    this.documentoTipo = 'CNPJ',
    this.documentoNumero = '',
    this.inscricaoEstadual = '',
    this.telefone = '',
    this.email = '',
    this.logradouro = '',
    this.bairro = '',
    this.cidade = '',
    this.uf = '',
    this.cep = '',
    this.pixTipo = 'CNPJ',
    this.pixChave = '',
    this.pixTitular = '',
    this.pixCidade = '',
    this.banco = '',
    this.agencia = '',
    this.contaBancaria = '',
    this.tipoConta = 'CORRENTE',
    this.titularConta = '',
    List<Maquininha>? maquininhas,
    this.operador = 'Caixa Principal',
    this.fundoTrocoPadrao = 100,
    this.mensagemRodape = 'Agradecemos a sua preferência! Volte sempre.',
    this.modoImpressao = 'BOBINA_80MM',
    this.permitirVendaSemEstoque = false,
    this.somBeep = true,
  }) : maquininhas = maquininhas ?? [];

  String nomeFantasia, razaoSocial, documentoTipo, documentoNumero, inscricaoEstadual, telefone, email;
  String logradouro, bairro, cidade, uf, cep;
  String pixTipo, pixChave, pixTitular, pixCidade;
  String banco, agencia, contaBancaria, tipoConta, titularConta;
  List<Maquininha> maquininhas;
  String operador;
  double fundoTrocoPadrao;
  String mensagemRodape;
  String modoImpressao;

  /// Mantido apenas por compatibilidade com o AI Studio: o banco NUNCA aceita
  /// saldo negativo, então esta opção não altera o bloqueio de estoque.
  bool permitirVendaSemEstoque;
  bool somBeep;

  bool get pixConfigurado => pixChave.trim().isNotEmpty;

  factory ContaEstabelecimento.fromJson(Map<String, dynamic> j, {String nomeLojaPadrao = ''}) {
    final end = Map<String, dynamic>.from((j['endereco'] as Map?) ?? const {});
    final pix = Map<String, dynamic>.from((j['dadosPix'] as Map?) ?? const {});
    final bnc = Map<String, dynamic>.from((j['dadosBancarios'] as Map?) ?? const {});
    final pdv = Map<String, dynamic>.from((j['configPDV'] as Map?) ?? const {});
    return ContaEstabelecimento(
      nomeFantasia: _s(j['nomeFantasia'], nomeLojaPadrao),
      razaoSocial: _s(j['razaoSocial']),
      documentoTipo: _s(j['documentoTipo'], 'CNPJ'),
      documentoNumero: _s(j['documentoNumero']),
      inscricaoEstadual: _s(j['inscricaoEstadual']),
      telefone: _s(j['telefone']),
      email: _s(j['email']),
      logradouro: _s(end['logradouro']),
      bairro: _s(end['bairro']),
      cidade: _s(end['cidade']),
      uf: _s(end['uf']),
      cep: _s(end['cep']),
      pixTipo: _s(pix['tipoChave'], 'CNPJ'),
      pixChave: _s(pix['chave']),
      pixTitular: _s(pix['titularNome']),
      pixCidade: _s(pix['cidadeTitular']),
      banco: _s(bnc['banco']),
      agencia: _s(bnc['agencia']),
      contaBancaria: _s(bnc['conta']),
      tipoConta: _s(bnc['tipoConta'], 'CORRENTE'),
      titularConta: _s(bnc['titular']),
      maquininhas: [
        for (final m in (j['maquininhas'] as List? ?? const [])) Maquininha.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
      operador: _s(pdv['operadorNome'], 'Caixa Principal'),
      fundoTrocoPadrao: _n(pdv['fundoTrocoPadrao'], 100),
      mensagemRodape: _s(pdv['mensagemRodape'], 'Agradecemos a sua preferência! Volte sempre.'),
      modoImpressao: _s(pdv['modoImpressao'], 'BOBINA_80MM'),
      permitirVendaSemEstoque: pdv['permitirVendaSemEstoque'] == true,
      somBeep: pdv['habilitarSomBeep'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'nomeFantasia': nomeFantasia,
    'razaoSocial': razaoSocial,
    'documentoTipo': documentoTipo,
    'documentoNumero': documentoNumero,
    'inscricaoEstadual': inscricaoEstadual,
    'telefone': telefone,
    'email': email,
    'endereco': {'logradouro': logradouro, 'bairro': bairro, 'cidade': cidade, 'uf': uf, 'cep': cep},
    'dadosPix': {'tipoChave': pixTipo, 'chave': pixChave, 'titularNome': pixTitular, 'cidadeTitular': pixCidade},
    'dadosBancarios': {'banco': banco, 'agencia': agencia, 'conta': contaBancaria, 'tipoConta': tipoConta, 'titular': titularConta},
    'maquininhas': [for (final m in maquininhas) m.toJson()],
    'configPDV': {
      'operadorNome': operador,
      'fundoTrocoPadrao': fundoTrocoPadrao,
      'mensagemRodape': mensagemRodape,
      'modoImpressao': modoImpressao,
      'permitirVendaSemEstoque': permitirVendaSemEstoque,
      'habilitarSomBeep': somBeep,
    },
    'statusAtivacao': 'ATIVO',
  };
}

class MovimentoCaixa {
  MovimentoCaixa({required this.id, required this.tipo, required this.valor, required this.motivo, required this.operador, required this.dataHora});
  final String id;
  final String tipo; // SANGRIA | SUPRIMENTO
  final double valor;
  final String motivo;
  final String operador;
  final DateTime dataHora;

  factory MovimentoCaixa.fromJson(Map<String, dynamic> j) => MovimentoCaixa(
    id: _s(j['id']),
    tipo: _s(j['tipo'], 'SUPRIMENTO'),
    valor: _n(j['valor']),
    motivo: _s(j['motivo']),
    operador: _s(j['operador']),
    dataHora: DateTime.tryParse(_s(j['dataHora'])) ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo,
    'valor': valor,
    'motivo': motivo,
    'operador': operador,
    'dataHora': dataHora.toUtc().toIso8601String(),
  };
}

/// Turno de caixa. Os totais de venda NÃO são guardados: são calculados do
/// histórico de vendas desde [abertaEm] (fonte única da verdade). Só o fundo de
/// troco e as sangrias/reforços ficam gravados na sessão.
class SessaoCaixa {
  SessaoCaixa({
    required this.id,
    required this.abertaEm,
    required this.operador,
    required this.fundoTroco,
    List<MovimentoCaixa>? movimentos,
    this.fechada = false,
  }) : movimentos = movimentos ?? [];

  final String id;
  final DateTime abertaEm;
  final String operador;
  final double fundoTroco;
  final List<MovimentoCaixa> movimentos;
  final bool fechada;

  double get totalSuprimento => movimentos.where((m) => m.tipo == 'SUPRIMENTO').fold(0.0, (s, m) => s + m.valor);
  double get totalSangria => movimentos.where((m) => m.tipo == 'SANGRIA').fold(0.0, (s, m) => s + m.valor);

  factory SessaoCaixa.fromRow(Map<String, dynamic> r) {
    final d = Map<String, dynamic>.from((r['dados'] as Map?) ?? const {});
    return SessaoCaixa(
      id: _s(r['id']),
      abertaEm: DateTime.tryParse(_s(r['aberta_em'])) ?? DateTime.now(),
      operador: _s(d['operador'], 'Caixa Principal'),
      fundoTroco: _n(d['fundoTrocoInicial'], 100),
      movimentos: [
        for (final m in (d['movimentacoes'] as List? ?? const [])) MovimentoCaixa.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
      fechada: _s(r['status']) == 'FECHADO',
    );
  }

  Map<String, dynamic> dadosJson() => {
    'operador': operador,
    'fundoTrocoInicial': fundoTroco,
    'movimentacoes': [for (final m in movimentos) m.toJson()],
  };
}
