import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import '../config/app_config.dart';

class UploadResultado {
  final String? downloadUrl;
  final String? fileKey;

  const UploadResultado({this.downloadUrl, this.fileKey});
}

class UploadFotoService {
  static Future<UploadResultado?> uploadBase64({
    required String base64,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final idToken = await user.getIdToken(true);
      if (idToken == null) throw Exception('Falha ao obter token');

      final response = await http
          .post(
            Uri.parse('${AppConfig.vercelApiUrl}/uploadB2'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'base64': base64,
              'fileName': fileName,
              'contentType': contentType,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UploadResultado(
          downloadUrl: data['downloadUrl'] as String?,
          fileKey: data['fileKey'] as String?,
        );
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Erro desconhecido';
        throw Exception('Upload falhou: $error');
      }
    } catch (e) {
      log('🔴 [UPLOAD SERVICE] Erro: $e');
      rethrow;
    }
  }

  /// Gera uma URL de acesso temporária (7 dias) para uma foto já enviada ao B2.
  static Future<String?> buscarUrlFoto(String fileKey) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final idToken = await user.getIdToken();
      if (idToken == null) return null;

      final uri = Uri.parse(
        '${AppConfig.vercelApiUrl}/fotoUrl?fileKey=${Uri.encodeComponent(fileKey)}',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $idToken'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['downloadUrl'] as String?;
      }
      log('🔴 [FOTO URL] HTTP ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      log('🔴 [FOTO URL] Erro: $e');
      return null;
    }
  }
}
