import 'dart:convert';
import 'package:http/http.dart' as http;

class CepResultado {
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
  final bool erro;

  CepResultado({
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
    this.erro = false,
  });

  factory CepResultado.vazio() {
    return CepResultado(logradouro: '', bairro: '', cidade: '', uf: '', erro: true);
  }
}

class CepService {
  static Future<CepResultado> buscar(String cep) async {
    final limpo = cep.replaceAll(RegExp(r'[^\d]'), '');
    if (limpo.length != 8) return CepResultado.vazio();

    try {
      final response = await http
          .get(Uri.parse('https://viacep.com.br/ws/$limpo/json/'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return CepResultado.vazio();

      final dados = jsonDecode(response.body);
      if (dados['erro'] == true) return CepResultado.vazio();

      return CepResultado(
        logradouro: dados['logradouro'] ?? '',
        bairro: dados['bairro'] ?? '',
        cidade: dados['localidade'] ?? '',
        uf: dados['uf'] ?? '',
      );
    } catch (_) {
      return CepResultado.vazio();
    }
  }
}
