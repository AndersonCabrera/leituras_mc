class Plano {
  final String id;
  final String nome;
  final String descricao;
  final int precoCentavos;
  final int limiteCondominios;
  final int limiteLeituristas;
  final bool relatoriosPersonalizados;
  final bool marcaPropria;

  const Plano({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.precoCentavos,
    required this.limiteCondominios,
    required this.limiteLeituristas,
    required this.relatoriosPersonalizados,
    required this.marcaPropria,
  });

  double get precoReal => precoCentavos / 100;
  String get precoFormatado => 'R\$${precoReal.toStringAsFixed(2)}';

  bool get ilimitadoCondominios => limiteCondominios == -1;
  bool get ilimitadoLeituristas => limiteLeituristas == -1;
  bool get isGratis => precoCentavos == 0;

  String get limiteCondominiosTexto =>
      ilimitadoCondominios ? 'Ilimitados' : 'Até $limiteCondominios';

  String get limiteLeituristasTexto =>
      ilimitadoLeituristas ? 'Ilimitados' : 'Até $limiteLeituristas';

  static const List<Plano> planos = [
    Plano(
      id: 'gratis',
      nome: 'Grátis',
      descricao: 'Para começar',
      precoCentavos: 0,
      limiteCondominios: 3,
      limiteLeituristas: 3,
      relatoriosPersonalizados: false,
      marcaPropria: false,
    ),
    Plano(
      id: 'premium',
      nome: 'Premium',
      descricao: 'Para administradoras em crescimento',
      precoCentavos: 12700,
      limiteCondominios: 15,
      limiteLeituristas: 15,
      relatoriosPersonalizados: true,
      marcaPropria: false,
    ),
    Plano(
      id: 'super_premium',
      nome: 'Super Premium',
      descricao: 'Para administradoras de grande porte',
      precoCentavos: 29700,
      limiteCondominios: -1,
      limiteLeituristas: -1,
      relatoriosPersonalizados: true,
      marcaPropria: true,
    ),
  ];

  static Plano fromId(String id) {
    return planos.firstWhere((p) => p.id == id, orElse: () => planos[0]);
  }
}
