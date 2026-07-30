class Pagamento {
  final String id;
  final String idAdministradora;
  final String idMercadoPago;
  final int valorCentavos;
  final String status;
  final String metodo;
  final DateTime data;
  final String plano;

  const Pagamento({
    required this.id,
    required this.idAdministradora,
    required this.idMercadoPago,
    required this.valorCentavos,
    required this.status,
    required this.metodo,
    required this.data,
    required this.plano,
  });

  double get valorReal => valorCentavos / 100;
  String get valorFormatado => 'R\$${valorReal.toStringAsFixed(2)}';

  factory Pagamento.fromMap(String id, Map<String, dynamic> map) {
    return Pagamento(
      id: id,
      idAdministradora: map['id_administradora'] ?? '',
      idMercadoPago: map['id_mercadopago'] ?? '',
      valorCentavos: map['valor'] ?? 0,
      status: map['status'] ?? 'pending',
      metodo: map['metodo'] ?? 'unknown',
      data: (map['data'] as dynamic)?.toDate() ?? DateTime.now(),
      plano: map['plano'] ?? '',
    );
  }
}
