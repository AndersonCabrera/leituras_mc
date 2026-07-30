class Assinatura {
  final String id;
  final String idAdministradora;
  final String plano;
  final String status;
  final DateTime? dataInicioTrial;
  final DateTime? dataFimTrial;
  final DateTime? dataProximoCobranca;
  final String? idMercadoPago;
  final String? statusMercadoPago;

  const Assinatura({
    required this.id,
    required this.idAdministradora,
    required this.plano,
    required this.status,
    this.dataInicioTrial,
    this.dataFimTrial,
    this.dataProximoCobranca,
    this.idMercadoPago,
    this.statusMercadoPago,
  });

  bool get isActive =>
      status == 'active' || status == 'trial';

  bool get isTrial => status == 'trial';

  bool get isExpired => status == 'expired' || status == 'cancelled';

  bool get isPastDue => status == 'past_due';

  bool get trialExpirado {
    if (dataFimTrial == null) return false;
    return DateTime.now().isAfter(dataFimTrial!);
  }

  int get diasRestantesTrial {
    if (dataFimTrial == null) return 0;
    return dataFimTrial!.difference(DateTime.now()).inDays.clamp(0, 999);
  }

  factory Assinatura.fromMap(
      String id, Map<String, dynamic> map) {
    return Assinatura(
      id: id,
      idAdministradora: map['id_administradora'] ?? '',
      plano: map['plano'] ?? 'gratis',
      status: map['status'] ?? 'trial',
      dataInicioTrial: (map['data_inicio_trial'] as dynamic)?.toDate(),
      dataFimTrial: (map['data_fim_trial'] as dynamic)?.toDate(),
      dataProximoCobranca:
          (map['data_proximo_cobranca'] as dynamic)?.toDate(),
      idMercadoPago: map['id_mercadopago'],
      statusMercadoPago: map['status_mercadopago'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id_administradora': idAdministradora,
      'plano': plano,
      'status': status,
      'data_inicio_trial': dataInicioTrial,
      'data_fim_trial': dataFimTrial,
      'data_proximo_cobranca': dataProximoCobranca,
      'id_mercadopago': idMercadoPago,
      'status_mercadopago': statusMercadoPago,
    };
  }
}
