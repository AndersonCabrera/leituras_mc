import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/tela_login.dart';
import 'tela_cadastro_administradora.dart';
import 'tela_criar_acesso_cliente.dart';
import 'tela_importacao_massa.dart';
import '../../core/theme.dart'; // 💡 IMPORTAÇÃO DO TEMA

class TelaSuperAdminDashboard extends StatefulWidget {
  const TelaSuperAdminDashboard({super.key});

  @override
  State<TelaSuperAdminDashboard> createState() =>
      _TelaSuperAdminDashboardState();
}

class _TelaSuperAdminDashboardState extends State<TelaSuperAdminDashboard> {
  void _abrirDialogImportacao(String idAdministradora) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TelaImportacaoMassa(idAdministradora: idAdministradora),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Cores dinâmicas que respeitam o tema
    Color azulEscuro = isDark
        ? Colors.blueGrey.shade900
        : const Color(0xFF0A192F);
    Color azul = const Color(0xFF0D47A1);
    Color fundo = Theme.of(context).scaffoldBackgroundColor;
    Color corCartao = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color corTextoTitulo = isDark ? Colors.white : const Color(0xFF1A1A2E);
    Color corBorda = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Painel Master SaaS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: azulEscuro,
        elevation: 0,
        actions: [
          const BotaoTrocaTema(corIcone: Colors.white), // 💡 BOTÃO AQUI!
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Sair do Sistema',
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
                    color: azulEscuro,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Olá, MC Prestadora!',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Gestão de Clientes',
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
                          context, // Adicionado context para ler o tema
                          'Empresas',
                          Icons.domain_rounded,
                          azul,
                          FirebaseFirestore.instance
                              .collection('administradoras')
                              .snapshots(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard(
                          context, // Adicionado context para ler o tema
                          'Gestores',
                          Icons.admin_panel_settings_rounded,
                          Colors.amber.shade700,
                          FirebaseFirestore.instance
                              .collection('usuarios')
                              .where('cargo', isEqualTo: 'admin')
                              .snapshots(),
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: FutureBuilder<Map<String, dynamic>>(
                future: () async {
                  int totalApartamentos = 0;
                  int leiturasConcluidas = 0;
                  DateTime agora = DateTime.now();
                  String mesAnoFiltro = "${agora.month}_${agora.year}";

                  var prediosSnapshot = await FirebaseFirestore.instance
                      .collection('predios')
                      .get();
                  for (var doc in prediosSnapshot.docs) {
                    var dados = doc.data();
                    if (dados['apartamentos'] != null) {
                      if (dados['apartamentos'] is List) {
                        totalApartamentos +=
                            (dados['apartamentos'] as List).length;
                      } else if (dados['apartamentos'] is num) {
                        totalApartamentos += (dados['apartamentos'] as num)
                            .toInt();
                      }
                    }
                  }

                  var leiturasSnapshot = await FirebaseFirestore.instance
                      .collection('leituras')
                      .get();
                  for (var doc in leiturasSnapshot.docs) {
                    if (doc.id.endsWith(mesAnoFiltro)) leiturasConcluidas++;
                  }

                  double progresso = totalApartamentos > 0
                      ? leiturasConcluidas / totalApartamentos
                      : 0.0;
                  return {
                    'total': totalApartamentos,
                    'concluidas': leiturasConcluidas,
                    'porcentagem': progresso > 1.0 ? 1.0 : progresso,
                  };
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: corCartao,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  var dadosOperacao =
                      snapshot.data ??
                      {'total': 0, 'concluidas': 0, 'porcentagem': 0.0};
                  double pctValor = dadosOperacao['porcentagem'] as double;
                  int pctTexto = (pctValor * 100).toInt();

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: corCartao,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progresso Global da Operação',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: corTextoTitulo,
                              ),
                            ),
                            Text(
                              '$pctTexto%',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: pctValor,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade200,
                          color: pctTexto == 100
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${dadosOperacao['concluidas']} de ${dadosOperacao['total']} medidores lidos neste mês.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expansão do Sistema',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corTextoTitulo,
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const TelaCadastroAdministradora(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [azul, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: azul.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.domain_add_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Novo Cliente',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'Cadastrar uma nova administradora',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              child: Text(
                'Clientes Ativos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: corTextoTitulo,
                ),
              ),
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('administradoras')
                .orderBy('data_cadastro', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_center_rounded,
                          size: 60,
                          color: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Nenhum cliente cadastrado.',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.grey.shade400 : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    var doc = snapshot.data!.docs[index];
                    var adminData = doc.data() as Map<String, dynamic>;
                    String nome = adminData['nome_empresa'] ?? 'Empresa';
                    String inicial = nome.isNotEmpty
                        ? nome[0].toUpperCase()
                        : 'E';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: corCartao,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: corBorda),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              0,
                            ),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: azulEscuro.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  inicial,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.blue.shade300
                                        : azulEscuro,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              nome,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: corTextoTitulo,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'CNPJ: ${adminData['cnpj'] ?? 'Não informado'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Criar Acesso',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.blue.shade300
                                          : azul,
                                      side: BorderSide(
                                        color: isDark
                                            ? Colors.blue.shade300.withOpacity(
                                                0.5,
                                              )
                                            : azul.withOpacity(0.5),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TelaCriarAcessoCliente(
                                                idAdministradora: doc.id,
                                                nomeEmpresa: nome,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.paste_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Importar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () =>
                                        _abrirDialogImportacao(doc.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: snapshot.data!.docs.length),
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
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
  ) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Container(
      padding: const EdgeInsets.all(16),
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
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
