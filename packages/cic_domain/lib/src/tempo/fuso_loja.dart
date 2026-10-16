import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Fuso padrão documentado do contrato quando a loja não configurou outro.
const String fusoPadraoLoja = 'America/Sao_Paulo';

/// Relógio injetável. O domínio nunca chama `DateTime.now()` diretamente.
abstract interface class Relogio {
  /// Instante atual em UTC.
  DateTime agoraUtc();
}

class RelogioSistema implements Relogio {
  const RelogioSistema();

  @override
  DateTime agoraUtc() => DateTime.now().toUtc();
}

class RelogioFixo implements Relogio {
  RelogioFixo(DateTime instante) : _instante = instante.toUtc();

  DateTime _instante;

  void ajustar(DateTime instante) => _instante = instante.toUtc();

  @override
  DateTime agoraUtc() => _instante;
}

/// Data civil (sem hora) no calendário da loja.
class DataCivil implements Comparable<DataCivil> {
  const DataCivil(this.ano, this.mes, this.dia);

  final int ano;
  final int mes;
  final int dia;

  /// Soma dias pelo calendário, sem passar por durações de 24h.
  DataCivil somarDias(int dias) {
    final d = DateTime.utc(ano, mes, dia + dias);
    return DataCivil(d.year, d.month, d.day);
  }

  @override
  int compareTo(DataCivil outra) =>
      DateTime.utc(ano, mes, dia).compareTo(DateTime.utc(outra.ano, outra.mes, outra.dia));

  @override
  bool operator ==(Object other) =>
      other is DataCivil && other.ano == ano && other.mes == mes && other.dia == dia;

  @override
  int get hashCode => Object.hash(ano, mes, dia);

  /// `AAAA-MM-DD`.
  @override
  String toString() =>
      '${ano.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}';
}

/// Converte instantes UTC em datas civis da loja e vice-versa, usando a base
/// IANA (inclui eventual horário de verão), independente do fuso do aparelho.
class FusoLoja {
  FusoLoja._(this.nome, this._local);

  final String nome;
  final tz.Location _local;

  static bool _baseCarregada = false;

  /// Lança [ArgumentError] para nome de fuso inexistente; nunca cai
  /// silenciosamente no fuso do aparelho.
  factory FusoLoja(String nome) {
    if (!_baseCarregada) {
      tzdata.initializeTimeZones();
      _baseCarregada = true;
    }
    try {
      return FusoLoja._(nome, tz.getLocation(nome));
    } on tz.LocationNotFoundException {
      throw ArgumentError.value(nome, 'nome', 'Fuso horário IANA desconhecido');
    }
  }

  factory FusoLoja.padrao() => FusoLoja(fusoPadraoLoja);

  DataCivil dataCivilDe(DateTime instante) {
    final local = tz.TZDateTime.from(instante.toUtc(), _local);
    return DataCivil(local.year, local.month, local.day);
  }

  /// Instante UTC da 00:00 local daquela data civil.
  DateTime inicioDoDiaUtc(DataCivil data) =>
      tz.TZDateTime(_local, data.ano, data.mes, data.dia).toUtc();

  /// Deslocamento do fuso naquele instante (ex.: -03:00), para serialização.
  Duration deslocamentoEm(DateTime instante) =>
      tz.TZDateTime.from(instante.toUtc(), _local).timeZoneOffset;
}
