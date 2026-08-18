import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';
import '../config/app_config.dart';

class UploadFotoService {
  static Future<String?> uploadBase64({
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
            Uri.parse('${AppConfig.vercelApiUrl}/uploadFoto'),
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
        return data['downloadUrl'] as String?;
      } else {
        final error = jsonDecode(response.body)['error'] ?? 'Erro desconhecido';
        throw Exception('Upload falhou: $error');
      }
    } catch (e) {
      log('🔴 [UPLOAD SERVICE] Erro: $e');
      rethrow;
    }
  }
}