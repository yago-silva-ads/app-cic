import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/format.dart';
import '../core/pix.dart';
import '../core/theme.dart';
import '../data/auth_service.dart';
import '../data/conta.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

const _bancos = [
  'Nubank (260)', 'Banco do Brasil (001)', 'Itaú Unibanco (341)', 'Bradesco (237)',
  'Caixa Econômica Federal (104)', 'Santander Brasil (033)', 'Banco Inter (077)',
  'PagBank / PagSeguro (290)', 'Stone Pagamentos (197)', 'C6 Bank (336)',
  'Mercado Pago (323)', 'Sicoob (756)', 'Sicredi (748)', 'Outro Banco / Cooperativa',
];

const _modelos = [
  ('STONE', 'Stone Smart Balcão', 1.29, 3.19, 1),
  ('PAGBANK', 'PagBank Moderninha / Smart', 1.39, 3.49, 0),
  ('MERCADOPAGO', 'Mercado Pago Point Pro 2', 1.45, 3.39, 0),
  ('CIELO', 'Cielo Lio / Flash', 1.49, 3.69, 1),
  ('REDE', 'Rede Smart Itaú', 1.35, 3.29, 1),
  ('INFINITEPAY', 'InfinitePay Smart', 0.98, 2.89, 1),
  ('SUMUP', 'SumUp Solo', 1.35, 3.30, 1),
];

Future<void> abrirContaModal(BuildContext context, AppState estado) =>
    showDialog(context: context, builder: (_) => ContaModal(estado: estado));

/// "Conta da Sua Loja & Frente de Caixa" (porte de `ContaModal.tsx`).
class ContaModal extends StatefulWidget {
  const ContaModal({super.key, required this.estado});
  final AppState estado;

  @override
  State<ContaModal> createState() => _ContaModalState();
}

class _ContaModalState extends State<ContaModal> {
  late ContaEstabelecimento _c;
  int _aba = 0;
  bool _salvando = false;
  String? _erro;

  late final Map<String, TextEditingController> _t;

  TextEditingController _ctl(String k, String v) => _t.putIfAbsent(k, () => TextEditingController(text: v));

  @override
  void initState() {
    super.initState();
    _t = {};
    // Cópia de trabalho: cancelar não altera a conta em uso.
    _c = ContaEstabelecimento.fromJson(widget.estado.conta.toJson());
    if (_c.nomeFantasia.isEmpty) _c.nomeFantasia = widget.estado.usuario?.lojaNome ?? '';
    // Cria todos os campos já na abertura: abas não visitadas não podem
    // sobrescrever dados existentes com texto vazio ao salvar.
    final inicial = <String, String>{
      'nomeFantasia': _c.nomeFantasia, 'razaoSocial': _c.razaoSocial, 'documentoNumero': _c.documentoNumero,
      'ie': _c.inscricaoEstadual, 'telefone': _c.telefone, 'email': _c.email, 'logradouro': _c.logradouro,
      'bairro': _c.bairro, 'cidade': _c.cidade, 'uf': _c.uf, 'cep': _c.cep, 'pixChave': _c.pixChave,
      'pixTitular': _c.pixTitular, 'pixCidade': _c.pixCidade, 'agencia': _c.agencia,
      'contaBancaria': _c.contaBancaria, 'titularConta': _c.titularConta, 'operador': _c.operador,
      'rodape': _c.mensagemRodape, 'fundo': _c.fundoTrocoPadrao.toStringAsFixed(2).replaceAll('.', ','),
    };
    inicial.forEach(_ctl);
    for (final m in _c.maquininhas) {
      _ctl('maq-nome-${m.id}', m.nome);
      _ctl('maq-deb-${m.id}', '${m.taxaDebito}');
      _ctl('maq-cre-${m.id}', '${m.taxaCredito}');
      _ctl('maq-prazo-${m.id}', '${m.prazoDias}');
    }
  }

  @override
  void dispose() {
    for (final c in _t.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    String v(String k) => AuthService.limpar(_t[k]?.text ?? '', 120);
    // Lê todos os campos digitados para o modelo.
    _c
      ..nomeFantasia = v('nomeFantasia')
      ..razaoSocial = v('razaoSocial')
      ..documentoNumero = AuthService.limpar(_t['documentoNumero']?.text ?? '', 25)
      ..inscricaoEstadual = v('ie')
      ..telefone = AuthService.limpar(_t['telefone']?.text ?? '', 25)
      ..email = v('email')
      ..logradouro = v('logradouro')
      ..bairro = v('bairro')
      ..cidade = v('cidade')
      ..uf = AuthService.limpar(_t['uf']?.text ?? '', 2).toUpperCase()
      ..cep = AuthService.limpar(_t['cep']?.text ?? '', 10)
      ..pixChave = AuthService.limpar(_t['pixChave']?.text ?? '', 100)
      ..pixTitular = v('pixTitular')
      ..pixCidade = v('pixCidade')
      ..agencia = AuthService.limpar(_t['agencia']?.text ?? '', 15)
      ..contaBancaria = AuthService.limpar(_t['contaBancaria']?.text ?? '', 25)
      ..titularConta = v('titularConta')
      ..operador = v('operador')
      ..mensagemRodape = AuthService.limpar(_t['rodape']?.text ?? '', 200);
    final fundo = lerDecimal(_t['fundo']?.text ?? '');
    if (fundo != null && fundo >= 0) _c.fundoTrocoPadrao = fundo;
    for (final m in _c.maquininhas) {
      m.nome = AuthService.limpar(_t['maq-nome-${m.id}']?.text ?? m.nome, 80);
      m.taxaDebito = lerDecimal(_t['maq-deb-${m.id}']?.text ?? '') ?? m.taxaDebito;
      m.taxaCredito = lerDecimal(_t['maq-cre-${m.id}']?.text ?? '') ?? m.taxaCredito;
      m.prazoDias = lerInteiro(_t['maq-prazo-${m.id}']?.text ?? '') ?? m.prazoDias;
    }

    if (_c.nomeFantasia.isEmpty) {
      setState(() {
        _aba = 0;
        _erro = 'Informe o nome fantasia da loja.';
      });
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.estado.salvarConta(_c);
      if (mounted) {
        Navigator.pop(context);
        aviso(context, 'Dados salvos! Frente de Caixa e maquininhas atualizados.');
      }
    } on ErroCic catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final abas = [
      ('1. Minha Loja', LucideIcons.building2),
      ('2. Conta & PIX', LucideIcons.landmark),
      ('3. Maquininhas (${_c.maquininhas.length})', LucideIcons.creditCard),
      ('4. Caixa & Cupom', LucideIcons.printer),
    ];
    return Dialog(
      backgroundColor: c.isLight ? Colors.white : const Color(0xFF15171B),
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: c.isLight ? c.cardBorder : const Color(0xFF2A2E37))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CicIconeCaixa(LucideIcons.store, tom: BadgeTom.ouro, tamanho: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Conta da Sua Loja & Frente de Caixa', style: TextStyle(color: c.text, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Dados da empresa, conta de recebimento e maquininhas de balcão.', style: TextStyle(color: c.textMuted, fontSize: 12)),
                ]),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: Icon(LucideIcons.x, size: 20, color: c.textMuted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: c.isLight ? const Color(0xFFF8FAFC) : const Color(0xFF1B1D23),
            child: Row(children: [
              Icon(LucideIcons.shieldCheck, size: 15, color: c.emerald),
              const SizedBox(width: 8),
              Expanded(child: Text('Salvo no banco, isolado na sua loja', style: TextStyle(color: c.textSoft, fontSize: 12, fontWeight: FontWeight.w500))),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              for (var i = 0; i < abas.length; i++)
                InkWell(
                  onTap: () => setState(() => _aba = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _aba == i ? c.gold : Colors.transparent, width: 2))),
                    child: Row(children: [
                      Icon(abas[i].$2, size: 16, color: _aba == i ? c.gold : c.textMuted),
                      const SizedBox(width: 8),
                      Text(abas[i].$1, style: TextStyle(color: _aba == i ? c.gold : c.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
            ]),
          ),
          Divider(height: 1, color: c.cardBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_erro != null) ...[CicErroBanner(mensagem: _erro!), const SizedBox(height: 14)],
                [_empresa, _bancoPix, _maquininhas, _pdv][_aba](c),
              ]),
            ),
          ),
          Divider(height: 1, color: c.cardBorder),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: CicBotao('Cancelar', secundario: true, onPressed: _salvando ? null : () => Navigator.pop(context))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: CicBotao('Salvar e Ativar', icone: LucideIcons.save, carregando: _salvando, onPressed: _salvar)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _linha(List<Widget> filhos) => LayoutBuilder(builder: (context, b) {
    if (b.maxWidth < 520) {
      return Column(children: [for (final f in filhos) Padding(padding: const EdgeInsets.only(bottom: 14), child: f)]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < filhos.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: filhos[i]),
        ],
      ]),
    );
  });

  Widget _drop(CicPalette c, String rotulo, String valor, List<String> opcoes, ValueChanged<String> onChanged, {Map<String, String>? nomes}) {
    final v = opcoes.contains(valor) ? valor : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(rotulo.toUpperCase(), style: TextStyle(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: v,
        isExpanded: true,
        dropdownColor: c.card,
        style: TextStyle(color: c.text, fontSize: 13),
        decoration: const InputDecoration(),
        items: [for (final o in opcoes) DropdownMenuItem(value: o, child: Text(nomes?[o] ?? o, overflow: TextOverflow.ellipsis))],
        onChanged: (x) => x == null ? null : setState(() => onChanged(x)),
      ),
    ]);
  }

  Widget _empresa(CicPalette c) => Column(children: [
    _linha([
      CicCampo(rotulo: 'Nome fantasia da loja *', controller: _ctl('nomeFantasia', _c.nomeFantasia), icone: LucideIcons.store),
      CicCampo(rotulo: 'Razão social', controller: _ctl('razaoSocial', _c.razaoSocial)),
    ]),
    _linha([
      _drop(c, 'Tipo de documento', _c.documentoTipo, ['CNPJ', 'CPF'], (x) => _c.documentoTipo = x,
          nomes: {'CNPJ': 'CNPJ (PJ / MEI)', 'CPF': 'CPF (autônomo)'}),
      CicCampo(rotulo: 'Número do documento', controller: _ctl('documentoNumero', _c.documentoNumero), teclado: TextInputType.number),
      CicCampo(rotulo: 'Inscrição estadual', controller: _ctl('ie', _c.inscricaoEstadual), dica: 'Isento'),
    ]),
    _linha([
      CicCampo(rotulo: 'WhatsApp / telefone', controller: _ctl('telefone', _c.telefone), icone: LucideIcons.phone, teclado: TextInputType.phone),
      CicCampo(rotulo: 'E-mail', controller: _ctl('email', _c.email), icone: LucideIcons.mail, teclado: TextInputType.emailAddress),
    ]),
    _linha([
      CicCampo(rotulo: 'Endereço (rua e número)', controller: _ctl('logradouro', _c.logradouro), icone: LucideIcons.mapPin),
      CicCampo(rotulo: 'Bairro', controller: _ctl('bairro', _c.bairro)),
    ]),
    _linha([
      CicCampo(rotulo: 'Cidade', controller: _ctl('cidade', _c.cidade)),
      CicCampo(rotulo: 'UF', controller: _ctl('uf', _c.uf), maxLength: 2),
      CicCampo(rotulo: 'CEP', controller: _ctl('cep', _c.cep), teclado: TextInputType.number),
    ]),
  ]);

  Widget _bancoPix(CicPalette c) {
    final payload = _c.pixConfigurado
        ? gerarPayloadPix(
            chave: _t['pixChave']?.text.isNotEmpty == true ? _t['pixChave']!.text : _c.pixChave,
            nomeRecebedor: _t['pixTitular']?.text.isNotEmpty == true ? _t['pixTitular']!.text : (_c.pixTitular.isEmpty ? _c.nomeFantasia : _c.pixTitular),
            cidadeRecebedor: _t['pixCidade']?.text.isNotEmpty == true ? _t['pixCidade']!.text : (_c.pixCidade.isEmpty ? _c.cidade : _c.pixCidade),
            valor: 1,
            identificador: 'TESTE',
          )
        : null;
    return Column(children: [
      _secao(c, 'Chave PIX de recebimento', LucideIcons.qrCode),
      _linha([
        _drop(c, 'Tipo da chave', _c.pixTipo, ['CNPJ', 'CPF', 'CELULAR', 'EMAIL', 'ALEATORIA'], (x) => _c.pixTipo = x,
            nomes: {'CNPJ': 'CNPJ', 'CPF': 'CPF', 'CELULAR': 'Celular', 'EMAIL': 'E-mail', 'ALEATORIA': 'Chave aleatória'}),
        CicCampo(rotulo: 'Chave PIX', controller: _ctl('pixChave', _c.pixChave), onChanged: (_) => setState(() => _c.pixChave = _t['pixChave']!.text)),
      ]),
      _linha([
        CicCampo(rotulo: 'Nome do titular (até 25)', controller: _ctl('pixTitular', _c.pixTitular), maxLength: 25),
        CicCampo(rotulo: 'Cidade do titular (até 15)', controller: _ctl('pixCidade', _c.pixCidade), maxLength: 15),
      ]),
      if (payload != null)
        CicSub(
          child: Row(children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(6),
              child: QrImageView(data: payload, size: 92, backgroundColor: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Pré-visualização do QR de teste (R\$ 1,00). Escaneie no app do seu banco para confirmar que a chave está certa.',
                  style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.4)),
            ),
          ]),
        ),
      const SizedBox(height: 18),
      _secao(c, 'Conta bancária', LucideIcons.landmark),
      _linha([
        _drop(c, 'Banco', _c.banco, _bancos, (x) => _c.banco = x),
        _drop(c, 'Tipo de conta', _c.tipoConta, ['CORRENTE', 'POUPANCA', 'PAGAMENTO'], (x) => _c.tipoConta = x,
            nomes: {'CORRENTE': 'Corrente', 'POUPANCA': 'Poupança', 'PAGAMENTO': 'Pagamento'}),
      ]),
      _linha([
        CicCampo(rotulo: 'Agência', controller: _ctl('agencia', _c.agencia)),
        CicCampo(rotulo: 'Conta', controller: _ctl('contaBancaria', _c.contaBancaria)),
        CicCampo(rotulo: 'Titular', controller: _ctl('titularConta', _c.titularConta)),
      ]),
    ]);
  }

  Widget _secao(CicPalette c, String t, IconData i) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(i, size: 16, color: c.gold),
      const SizedBox(width: 8),
      Text(t.toUpperCase(), style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
    ]),
  );

  Widget _maquininhas(CicPalette c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Cadastre as taxas reais da sua maquininha para o PDV calcular quanto cai líquido na conta.',
        style: TextStyle(color: c.textMuted, fontSize: 12, height: 1.4)),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 8, children: [
      for (final m in _modelos)
        ActionChip(
          avatar: Icon(LucideIcons.plus, size: 13, color: c.gold),
          label: Text(m.$2, style: TextStyle(fontSize: 11, color: c.textSoft)),
          backgroundColor: c.sub,
          side: BorderSide(color: c.subBorder),
          onPressed: () => setState(() {
            _c.maquininhas.add(Maquininha(
              id: 'maq-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
              nome: m.$2,
              provedor: m.$1,
              taxaDebito: m.$3,
              taxaCredito: m.$4,
              prazoDias: m.$5,
            ));
          }),
        ),
    ]),
    const SizedBox(height: 14),
    if (_c.maquininhas.isEmpty)
      const CicVazio(icone: LucideIcons.creditCard, titulo: 'Nenhuma maquininha', texto: 'Toque em um modelo acima para adicionar e ajuste as taxas.'),
    for (final m in _c.maquininhas)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CicSub(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Expanded(child: CicCampo(rotulo: 'Nome', controller: _ctl('maq-nome-${m.id}', m.nome))),
              IconButton(
                tooltip: 'Remover',
                onPressed: () => setState(() => _c.maquininhas.removeWhere((x) => x.id == m.id)),
                icon: Icon(LucideIcons.trash2, size: 17, color: c.red),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: CicCampo(rotulo: 'Débito %', controller: _ctl('maq-deb-${m.id}', '${m.taxaDebito}'), teclado: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 10),
              Expanded(child: CicCampo(rotulo: 'Crédito %', controller: _ctl('maq-cre-${m.id}', '${m.taxaCredito}'), teclado: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 10),
              Expanded(child: CicCampo(rotulo: 'Prazo (dias)', controller: _ctl('maq-prazo-${m.id}', '${m.prazoDias}'), teclado: TextInputType.number)),
            ]),
          ]),
        ),
      ),
  ]);

  Widget _pdv(CicPalette c) => Column(children: [
    _linha([
      CicCampo(rotulo: 'Nome do operador de caixa', controller: _ctl('operador', _c.operador), icone: LucideIcons.userCheck),
      CicCampo(rotulo: 'Fundo de troco padrão (R\$)', controller: _ctl('fundo', _c.fundoTrocoPadrao.toStringAsFixed(2).replaceAll('.', ',')), teclado: const TextInputType.numberWithOptions(decimal: true)),
    ]),
    _linha([
      CicCampo(rotulo: 'Mensagem de rodapé do cupom', controller: _ctl('rodape', _c.mensagemRodape), maxLines: 2),
    ]),
    _linha([
      _drop(c, 'Modo de impressão', _c.modoImpressao, ['BOBINA_80MM', 'BOBINA_58MM', 'PADRAO_A4'], (x) => _c.modoImpressao = x,
          nomes: {'BOBINA_80MM': 'Bobina 80 mm', 'BOBINA_58MM': 'Bobina 58 mm', 'PADRAO_A4': 'Folha A4'}),
    ]),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: _c.somBeep,
      activeThumbColor: c.gold,
      onChanged: (v) => setState(() => _c.somBeep = v),
      title: Text('Som de bip ao adicionar item', style: TextStyle(color: c.text, fontSize: 13)),
    ),
    CicSub(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(LucideIcons.info, size: 16, color: c.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Venda sem estoque está sempre bloqueada: o saldo nunca fica negativo, e o banco confere isso em cada venda.',
              style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.4)),
        ),
      ]),
    ),
  ]);
}
