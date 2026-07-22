import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacaoService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // 💡 NOVO MÉTODO: Grava o token gerado diretamente no cadastro do utilizador
  static Future<void> salvarTokenNoBanco(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(userId).set(
          {'fcm_token': token, 'ultimo_login': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
        debugPrint(
          '🔔 Token FCM guardado com sucesso para o utilizador $userId',
        );
      }
    } catch (e) {
      debugPrint('Erro ao guardar token no Firestore: $e');
    }
  }

  static Future<void> inicializar() async {
    // 1. Requisitar permissão (Obrigatório no iOS e Android 13+)
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

    // 2. Obter o Token do dispositivo
    // (Este token é o "endereço" único deste telemóvel para receber mensagens)
    try {
      String? token = await _messaging.getToken();
      debugPrint('📲 FCM Token do Dispositivo: $token');
      // No futuro: Vamos salvar este token no Firestore, dentro do cadastro do usuário,
      // para podermos enviar mensagens direcionadas para ele!
    } catch (e) {
      debugPrint('Erro ao obter token FCM: $e');
    }

    // 3. Lidar com mensagens quando a app está ABERTA (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        '📬 Mensagem recebida em foreground: ${message.notification?.title}',
      );

      // Aqui poderíamos exibir um SnackBar (Toast) avisando o usuário
      if (message.notification != null) {
        debugPrint('Conteúdo: ${message.notification?.body}');
      }
    });
  }
}
