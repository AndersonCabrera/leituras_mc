import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/plano.dart';
import 'tela_planos.dart';

class TelaStatusAssinatura extends StatelessWidget {
  final String idAdministradora;

  const TelaStatusAssinatura({
    super.key,
    required this.idAdministradora,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color corCartao = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color corTexto = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meu Plano',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('administradoras')
            .doc(idAdministradora)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Dados não encontrados.'));
          }

          final dados = snapshot.data!.data() as Map<String, dynamic>;
          final planoId = dados['plano'] ?? 'gratis';
          final statusAssinatura = dados['status_assinatura'] ?? 'trial';
          final plano = Plano.fromId(planoId);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusHeader(
                plano: plano,
                status: statusAssinatura,
                isDark: isDark,
              ),
              const SizedBox(height: 24),
              if (statusAssinatura == 'trial')
                _TrialInfo(idAdministradora: idAdministradora),
              const SizedBox(height: 24),
              _LimitesCard(
                plano: plano,
                idAdministradora: idAdministradora,
                isDark: isDark,
                corCartao: corCartao,
                corTexto: corTexto,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final emailDoc = await FirebaseFirestore.instance
                        .collection('usuarios')
                        .where('id_administradora', isEqualTo: idAdministradora)
                        .where('cargo', isEqualTo: 'admin')
                        .limit(1)
                        .get();
                    final email = emailDoc.docs.isNotEmpty
                        ? emailDoc.docs.first.get('email') as String
                        : '';
                    final nome = dados['nome_empresa'] ?? '';

                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TelaPlanos(
                            idAdministradora: idAdministradora,
                            emailAdmin: email,
                            nomeEmpresa: nome,
                            planoAtual: planoId,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white),
                  label: Text(
                    statusAssinatura == 'trial'
                        ? 'ESCOLHER UM PLANO PAGO'
                        : 'MUDAR DE PLANO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final Plano plano;
  final String status;
  final bool isDark;

  const _StatusHeader({
    required this.plano,
    required this.status,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    IconData icone;
    String statusTexto;

    switch (status) {
      case 'active':
        icone = Icons.check_circle_rounded;
        statusTexto = 'Ativo';
        break;
      case 'trial':
        icone = Icons.free_breakfast_rounded;
        statusTexto = 'Trial Gratuito';
        break;
      case 'past_due':
        icone = Icons.warning_amber_rounded;
        statusTexto = 'Pagamento Pendente';
        break;
      case 'cancelled':
        icone = Icons.cancel_rounded;
        statusTexto = 'Cancelado';
        break;
      default:
        icone = Icons.help_rounded;
        statusTexto = status;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [plano.isGratis ? Colors.grey : Colors.blue.shade800, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icone, color: Colors.white, size: 56),
          const SizedBox(height: 12),
          Text(
            plano.nome,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusTexto,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          if (!plano.isGratis && plano.precoCentavos > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${plano.precoFormatado}/mês',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrialInfo extends StatelessWidget {
  final String idAdministradora;

  const _TrialInfo({required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Você está no período de teste grátis de 3 meses. Aproveite todos os recursos e escolha um plano para continuar.',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitesCard extends StatelessWidget {
  final Plano plano;
  final String idAdministradora;
  final bool isDark;
  final Color corCartao;
  final Color corTexto;

  const _LimitesCard({
    required this.plano,
    required this.idAdministradora,
    required this.isDark,
    required this.corCartao,
    required this.corTexto,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('predios')
          .where('id_administradora', isEqualTo: idAdministradora)
          .get(),
      builder: (context, snapshotPredios) {
        final qtdPredios = snapshotPredios.data?.docs.length ?? 0;

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('usuarios')
              .where('id_administradora', isEqualTo: idAdministradora)
              .where('cargo', isEqualTo: 'leiturista')
              .get(),
          builder: (context, snapshotLeit) {
            final qtdLeituristas = snapshotLeit.data?.docs.length ?? 0;

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: corCartao,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limites do Plano',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: corTexto,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _LimiteRow(
                    icon: Icons.apartment,
                    label: 'Condomínios',
                    atual: qtdPredios,
                    maximo: plano.limiteCondominios,
                    ilimitado: plano.ilimitadoCondominios,
                  ),
                  const SizedBox(height: 16),
                  _LimiteRow(
                    icon: Icons.people,
                    label: 'Leituristas',
                    atual: qtdLeituristas,
                    maximo: plano.limiteLeituristas,
                    ilimitado: plano.ilimitadoLeituristas,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LimiteRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int atual;
  final int maximo;
  final bool ilimitado;

  const _LimiteRow({
    required this.icon,
    required this.label,
    required this.atual,
    required this.maximo,
    required this.ilimitado,
  });

  @override
  Widget build(BuildContext context) {
    final double proporcao = ilimitado ? 0 : (atual / maximo).clamp(0.0, 1.0);
    final bool estourou = !ilimitado && atual >= maximo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: estourou ? Colors.red : Colors.grey),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 14)),
              ],
            ),
            Text(
              ilimitado ? '$atual / Ilimitado' : '$atual / $maximo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: estourou ? Colors.red : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (!ilimitado)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: proporcao,
              backgroundColor: Colors.grey.shade200,
              color: estourou ? Colors.red : Colors.blue,
              minHeight: 6,
            ),
          ),
      ],
    );
  }
}
