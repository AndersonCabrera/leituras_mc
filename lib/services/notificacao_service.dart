import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacaoService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // 💡 CORRIGIDO: Agora guarda o cargo e a administradora para o filtro do Servidor funcionar
  static Future<void> salvarTokenNoBanco(
    String userId,
    String idAdmin,
    String cargo,
  ) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(userId)
            .set({
              'fcm_token': token,
              'id_administradora': idAdmin,
              'cargo': cargo,
              'ultimo_login': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        debugPrint(
          '🔔 Token FCM guardado com sucesso para o utilizador $userId',
        );
      }
    } catch (e) {
      debugPrint('Erro ao guardar token no Firestore: $e');
    }
  }

  static Future<void> inicializar() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('🔔 Permissão de notificação concedida pelo usuário.');
    } else {
      debugPrint('🔕 Permissão de notificação negada ou não definida.');
    }

    try {
      String? token = await _messaging.getToken();
      debugPrint('📲 FCM Token do Dispositivo: $token');
    } catch (e) {
      debugPrint('Erro ao obter token FCM: $e');
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '📬 Mensagem recebida em foreground: ${message.notification?.title}',
      );

      if (message.notification != null) {
        debugPrint('Conteúdo: ${message.notification?.body}');
      }
    });
  }
}
