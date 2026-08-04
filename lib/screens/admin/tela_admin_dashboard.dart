import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/tela_login.dart';
import '../super_admin/tela_importacao_massa.dart';
import 'tela_configuracoes_marca.dart';
import 'tela_auditoria.dart';
import 'tela_fechamento_lote.dart';
import 'tela_enviar_notificacao.dart';
import 'tela_relatorios.dart';
import 'tela_gestao_predios.dart';
import 'tela_gestao_equipe.dart';
import '../pagamento/tela_planos.dart';
import '../pagamento/tela_status_assinatura.dart';
import '../../models/plano.dart';
import '../../core/theme.dart';

class TelaAdminDashboard extends StatelessWidget {
  final String idAdministradora;
  const TelaAdminDashboard({super.key, required this.idAdministradora});

  Future<void> _abrirPersonalizacaoPremium(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var doc = await FirebaseFirestore.instance
          .collection('administradoras')
          .doc(idAdministradora)
          .get();
        var dadosAdm = doc.data();
        var planoId = dadosAdm?['plano'] ?? 'gratis';
        var statusAssinatura = dadosAdm?['status_assinatura'] ?? 'trial';

      if (context.mounted) Navigator.pop(context);

      if (planoId == 'super_premium' && statusAssinatura == 'active') {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TelaConfiguracoesMarca(idAdministradora: idAdministradora),
            ),
          );
        }
      } else {
        if (context.mounted) _mostrarUpsellPremium(context);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _mostrarUpsellPremium(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.diamond_rounded, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text(
              'Recurso Exclusivo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'A personalização com marca própria (logótipo e contactos oficiais nos relatórios) é exclusiva do Plano Super Premium.\n\n'
          'Faça o upgrade e destaque a sua marca perante os síndicos!',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'AGORA NÃO',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _navegarPlanos(context);
            },
            icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
            label: const Text(
              'VER PLANOS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navegarPlanos(BuildContext context) async {
    final emailDoc = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('id_administradora', isEqualTo: idAdministradora)
        .where('cargo', isEqualTo: 'admin')
        .limit(1)
        .get();
    final email = emailDoc.docs.isNotEmpty
        ? emailDoc.docs.first.get('email') as String
        : '';

    final nomeDoc = await FirebaseFirestore.instance
        .collection('administradoras')
        .doc(idAdministradora)
        .get();
    final nome = nomeDoc.data()?['nome_empresa'] as String? ?? '';
    final planoAtual = nomeDoc.data()?['plano'] as String? ?? 'gratis';

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaPlanos(
            idAdministradora: idAdministradora,
            emailAdmin: email,
            nomeEmpresa: nome,
            planoAtual: planoAtual,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color azul = isDark ? Colors.blueGrey.shade900 : const Color(0xFF0D47A1);
    Color fundo = Theme.of(context).scaffoldBackgroundColor;
    Color corCartao = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color corTextoTitulo = isDark ? Colors.white : const Color(0xFF1A1A2E);
    Color corBorda = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Centro de Comando',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: azul,
        elevation: 0,
        actions: [
          const BotaoTrocaTema(corIcone: Colors.white),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EcraLogin()),
                );
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: azul,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Olá, Administrador!',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Visão Geral da Operação',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 85, left: 16, right: 16, bottom: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          context,
                          'Prédios',
                          Icons.apartment_rounded,
                          Colors.blue.shade700,
                          FirebaseFirestore.instance
                              .collection('predios')
                              .where('admin_id', isEqualTo: idAdministradora)
                              .snapshots(),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TelaGestaoPredios(adminId: idAdministradora),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard(
                          context,
                          'Equipe',
                          Icons.people_alt_rounded,
                          Colors.green.shade700,
                          FirebaseFirestore.instance
                              .collection('usuarios')
                              .where('id_administradora', isEqualTo: idAdministradora)
                              .where('cargo', isEqualTo: 'leiturista')
                              .snapshots(),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaListaEquipe(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _PlanoStatusCard(
                idAdministradora: idAdministradora,
                onVerPlanos: () => _navegarPlanos(context),
                isDark: isDark,
                corCartao: corCartao,
                corTextoTitulo: corTextoTitulo,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operações',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          context,
                          'Ver Relatórios',
                          'Consumos e PDF',
                          Icons.insert_chart_rounded,
                          Colors.orange.shade600,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TelaRelatoriosBusca(
                                  idAdministradora: idAdministradora,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionCard(
                          context,
                          'Gerir Roteiros',
                          'Acompanhar Leituras',
                          Icons.assignment_ind_rounded,
                          Colors.purple.shade600,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TelaGestaoPredios(adminId: idAdministradora),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          context,
                          'Auditoria',
                          'Revisar Anomalias',
                          Icons.policy_rounded,
                          Colors.red.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TelaAuditoria(idAdministradora: idAdministradora),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionCard(
                          context,
                          'Fechar Lote',
                          'Bloquear Mês',
                          Icons.lock_rounded,
                          Colors.indigo.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TelaFechamentoLote(idAdministradora: idAdministradora),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          context,
                          'Avisos Push',
                          'Notificar Equipe',
                          Icons.notifications_active_rounded,
                          Colors.blue.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TelaEnviarNotificacao(idAdministradora: idAdministradora),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionCard(
                          context,
                          'Importar',
                          'Unidades em Massa',
                          Icons.file_upload_rounded,
                          Colors.green.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaImportacaoMassa(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configurações',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 15),
                  _configTile(
                    context,
                    Icons.diamond_rounded,
                    'Marca Própria',
                    'Logótipo e contactos nos relatórios',
                    Colors.teal,
                    () => _abrirPersonalizacaoPremium(context),
                    isDark,
                    corCartao,
                    corTextoTitulo,
                    corBorda,
                  ),
                  const SizedBox(height: 10),
                  _configTile(
                    context,
                    Icons.credit_card_rounded,
                    'Meu Plano',
                    'Ver status da assinatura',
                    Colors.blue,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TelaStatusAssinatura(
                          idAdministradora: idAdministradora,
                        ),
                      ),
                    ),
                    isDark,
                    corCartao,
                    corTextoTitulo,
                    corBorda,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _configTile(
    BuildContext context,
    IconData icone,
    String titulo,
    String subtitulo,
    Color cor,
    VoidCallback onTap,
    bool isDark,
    Color corCartao,
    Color corTextoTitulo,
    Color corBorda,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: corCartao,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: corBorda),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? cor.withOpacity(0.2) : cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icone, color: cor),
        ),
        title: Text(
          titulo,
          style: TextStyle(fontWeight: FontWeight.w600, color: corTextoTitulo),
        ),
        subtitle: Text(
          subtitulo,
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _kpiCard(
    BuildContext context,
    String titulo,
    IconData icon,
    Color cor,
    Stream<QuerySnapshot> stream,
    VoidCallback onTap,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: cor, size: 28),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Text('...',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold));
                    int count = snapshot.data?.docs.length ?? 0;
                    return Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context,
    String titulo,
    String subtitulo,
    IconData icon,
    Color cor,
    VoidCallback onTap,
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: cor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cor, size: 24),
                ),
                const SizedBox(height: 16),
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor)),
                const SizedBox(height: 4),
                Text(subtitulo,
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanoStatusCard extends StatelessWidget {
  final String idAdministradora;
  final VoidCallback onVerPlanos;
  final bool isDark;
  final Color corCartao;
  final Color corTextoTitulo;

  const _PlanoStatusCard({
    required this.idAdministradora,
    required this.onVerPlanos,
    required this.isDark,
    required this.corCartao,
    required this.corTextoTitulo,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('administradoras')
          .doc(idAdministradora)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
        }

        var dados = snapshot.data?.data() as Map<String, dynamic>?;
        var planoId = dados?['plano'] ?? 'gratis';
        var status = dados?['status_assinatura'] ?? 'trial';
        var plano = Plano.fromId(planoId);

        IconData icone;
        Color corStatus;
        String statusTexto;

        switch (status) {
          case 'active':
            icone = Icons.check_circle_rounded;
            corStatus = Colors.green;
            statusTexto = 'Ativo';
            break;
          case 'trial':
            icone = Icons.free_breakfast_rounded;
            corStatus = Colors.orange;
            statusTexto = 'Trial Grátis';
            break;
          case 'past_due':
            icone = Icons.warning_amber_rounded;
            corStatus = Colors.red;
            statusTexto = 'Pagamento Pendente';
            break;
          default:
            icone = Icons.cancel_rounded;
            corStatus = Colors.grey;
            statusTexto = 'Inativo';
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: corCartao,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: status == 'past_due' ? Colors.red.shade300 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: corStatus.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icone, color: corStatus, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plano ${plano.nome}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: corTextoTitulo,
                      ),
                    ),
                    Text(
                      statusTexto,
                      style: TextStyle(fontSize: 12, color: corStatus),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onVerPlanos,
                child: Text(
                  status == 'trial' ? 'UPGRADE' : 'GERIR',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
