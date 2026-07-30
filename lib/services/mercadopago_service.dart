import 'dart:convert';
import 'package:http/http.dart' as http;

class MercadoPagoService {
  static const String _baseUrl = 'https://leituras-mc.vercel.app/api';

  static Future<Map<String, dynamic>> criarAssinatura({
    required String idAdministradora,
    required String plano,
    required String emailAdmin,
    required String nomeEmpresa,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/criar-assinatura'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_administradora': idAdministradora,
          'plano': plano,
          'email': emailAdmin,
          'nome_empresa': nomeEmpresa,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final erro = jsonDecode(response.body);
      return {'erro': erro['error'] ?? 'Erro ao criar assinatura'};
    } catch (e) {
      return {'erro': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> verificarStatus({
    required String idAdministradora,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/status-assinatura?id_administradora=$idAdministradora'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'erro': 'Erro ao verificar status'};
    } catch (e) {
      return {'erro': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> gerarFatura({
    required String idAdministradora,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/gerar-fatura'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_administradora': idAdministradora,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final erro = jsonDecode(response.body);
      return {'erro': erro['error'] ?? 'Erro ao gerar fatura'};
    } catch (e) {
      return {'erro': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> cancelarAssinatura({
    required String idAdministradora,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cancelar-assinatura'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_administradora': idAdministradora,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final erro = jsonDecode(response.body);
      return {'erro': erro['error'] ?? 'Erro ao cancelar'};
    } catch (e) {
      return {'erro': 'Erro de conexão: $e'};
    }
  }
}
