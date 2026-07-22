const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Inicializa os poderes de "Deus" (Admin) no banco de dados
admin.initializeApp();

/**
 * Função que é engatilhada sempre que um novo documento é 
 * criado na coleção "notificacoes_enviadas"
 */
exports.enviarNotificacaoPush = functions.firestore
  .document("notificacoes_enviadas/{docId}")
  .onCreate(async (snap, context) => {
    // Pega os dados que a aplicação móvel (Dashboard do Admin) salvou
    const dados = snap.data();
    const titulo = dados.titulo;
    const mensagem = dados.mensagem;
    const id_administradora = dados.id_administradora;
    const destinatario_tipo = dados.destinatario_tipo;
    const destinatario_id = dados.destinatario_id;

    try {
      let tokens = [];

      // 1. O Administrador escolheu mandar para TODOS os leituristas dele?
      if (destinatario_tipo === "equipe_inteira") {
        const snapshotUsuarios = await admin.firestore().collection("usuarios")
          .where("id_administradora", "==", id_administradora)
          .where("cargo", "==", "leiturista")
          .get();

        snapshotUsuarios.forEach(doc => {
          const fcm = doc.data().fcm_token;
          if (fcm) tokens.push(fcm); // Adiciona o token do telemóvel à lista
        });
      } 
      // 2. O Administrador escolheu um leiturista ESPECÍFICO?
      else if (destinatario_tipo === "individual" && destinatario_id) {
        const docUsuario = await admin.firestore().collection("usuarios").doc(destinatario_id).get();
        if (docUsuario.exists) {
          const fcm = docUsuario.data().fcm_token;
          if (fcm) tokens.push(fcm);
        }
      }

      // Se ninguém tiver entrado no aplicativo ainda para gerar um token, abortamos
      if (tokens.length === 0) {
        console.log("Nenhum token encontrado. A equipa ainda não tem o app instalado/logado.");
        return snap.ref.update({ status: "cancelado_sem_destinatarios" });
      }

      // 3. Monta o "Pacote" da Notificação Push
      const payload = {
        notification: {
          title: titulo,
          body: mensagem,
        }
      };

      // 4. Manda os servidores da Google dispararem a notificação!
      const response = await admin.messaging().sendMulticast({
        tokens: tokens,
        notification: payload.notification,
      });

      console.log(`Sucesso: ${response.successCount}, Falhas: ${response.failureCount}`);

      // 5. Atualiza o banco de dados dizendo que a notificação já foi enviada
      return snap.ref.update({ 
        status: "enviado", 
        sucessos: response.successCount,
        falhas: response.failureCount,
        data_envio: admin.firestore.FieldValue.serverTimestamp()
      });

    } catch (error) {
      console.error("Erro fatal ao enviar Push:", error);
      return snap.ref.update({ status: "erro", erro: error.message });
    }
  });