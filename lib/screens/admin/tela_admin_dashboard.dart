import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/tela_login.dart';
import 'tela_configuracoes_marca.dart';
import 'tela_auditoria.dart';
import 'tela_fechamento_lote.dart';

import 'tela_relatorios.dart';
import 'tela_gestao_predios.dart';
import 'tela_gestao_equipe.dart';
import '../../core/theme.dart';

class TelaAdminDashboard extends StatelessWidget {
  final String idAdministradora;
  const TelaAdminDashboard({super.key, required this.idAdministradora});

  void _mostrarAlertaBreve(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Funcionalidade em desenvolvimento para a próxima versão.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

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
      bool isPremium =
          (doc.data() as Map<String, dynamic>?)?['plano_premium'] == true;

      if (context.mounted) Navigator.pop(context);

      if (isPremium) {
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
            Icon(Icons.star_rounded, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text(
              'Recurso Premium',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'A personalização avançada de relatórios (inserção do seu Logótipo e contactos oficiais em PDF) é uma funcionalidade exclusiva do Plano White-Label.\n\n'
          'Destaque a sua marca perante os síndicos e passe uma imagem de topo. Fale com o nosso suporte para fazer o upgrade da sua conta!',
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
            onPressed: () async {
              Navigator.pop(ctx);
              final Uri url = Uri.parse(
                'https://wa.me/5551981285818?text=Ol%C3%A1%2C%20gostaria%20de%20fazer%20o%20upgrade%20para%20o%20Plano%20Premium%20(White-Label)%20no%20Leituras%20MC!',
              );

              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  throw 'Could not launch $url';
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Não foi possível abrir o WhatsApp. Instale o aplicativo ou acesse pelo navegador.',
                      ),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            icon: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'FAZER UPGRADE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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

  @override
  Widget build(BuildContext context) {
    // 💡 Deteta se o utilizador ativou o Modo Escuro
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // 💡 Cores Inteligentes: Adaptam-se automaticamente ao tema!
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
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
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
                  padding: const EdgeInsets.only(
                    top: 85,
                    left: 16,
                    right: 16,
                    bottom: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          context, // 💡 Passamos o context para ler o tema dentro do cartão
                          'Prédios',
                          Icons.apartment_rounded,
                          Colors.blue.shade700,
                          FirebaseFirestore.instance
                              .collection('predios')
                              .where(
                                'id_administradora',
                                isEqualTo: idAdministradora,
                              )
                              .snapshots(),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaGerenciarEquipes(
                                idAdministradora: idAdministradora,
                              ),
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
                              .where(
                                'id_administradora',
                                isEqualTo: idAdministradora,
                              )
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
                                builder: (_) => TelaGerenciarEquipes(
                                  idAdministradora: idAdministradora,
                                ),
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
                              builder: (_) => TelaAuditoria(
                                idAdministradora: idAdministradora,
                              ),
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
                              builder: (_) => TelaFechamentoLote(
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cadastros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: corCartao,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: corBorda),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blue.shade900.withOpacity(0.5)
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.domain_add_rounded,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          title: Text(
                            'Registar Novo Prédio',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: corTextoTitulo,
                            ),
                          ),
                          subtitle: Text(
                            'Adicionar condomínio e medidores',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaCadastroPredio(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                        Divider(height: 1, color: corBorda),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.green.shade900.withOpacity(0.5)
                                  : Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.person_add_rounded,
                              color: Colors.green.shade700,
                            ),
                          ),
                          title: Text(
                            'Registar Leiturista',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: corTextoTitulo,
                            ),
                          ),
                          subtitle: Text(
                            'Criar acesso para a equipe de campo',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaCadastroLeiturista(
                                idAdministradora: idAdministradora,
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
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Definições da Marca',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: corCartao,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: corBorda),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.teal.shade900.withOpacity(0.5)
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.brush_rounded,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      title: Text(
                        'Personalizar Relatórios',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: corTextoTitulo,
                        ),
                      ),
                      subtitle: Text(
                        'Upload de logótipo e contactos oficiais',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () => _abrirPersonalizacaoPremium(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                      return const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      );
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
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Colors.grey,
                    ),
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
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
