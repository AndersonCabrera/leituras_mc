import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/pagamento/tela_planos.dart';

class PlanoGate extends StatelessWidget {
  final String idAdministradora;
  final Widget child;
  final String? recurso;
  final bool mostrarDialogo;

  const PlanoGate({
    super.key,
    required this.idAdministradora,
    required this.child,
    this.recurso,
    this.mostrarDialogo = true,
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
          return const SizedBox();
        }

        final dados = snapshot.data?.data() as Map<String, dynamic>?;
        final status = dados?['status_assinatura'] ?? 'trial';

        if (status == 'active' || status == 'trial') {
          return child;
        }

        if (!mostrarDialogo) {
          return child;
        }

        return GestureDetector(
          onTap: () => _mostrarUpgrade(context),
          child: Stack(
            children: [
              Opacity(opacity: 0.4, child: AbsorbPointer(child: child)),
              Center(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, color: Colors.amber, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'Assinatura inativa',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Regularize sua assinatura para continuar usando.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _mostrarUpgrade(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('VER PLANOS'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarUpgrade(BuildContext context) {
    if (!mostrarDialogo) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(recurso != null ? Icons.lock_rounded : Icons.rocket_launch_rounded,
                color: Colors.amber, size: 28),
            const SizedBox(width: 10),
            const Text('Upgrade Necessário',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          recurso != null
              ? 'O recurso "$recurso" não está disponível no seu plano atual. Faça um upgrade para liberar esta e outras funcionalidades premium!'
              : 'Sua assinatura está inativa. Escolha um plano para continuar usando o sistema.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('AGORA NÃO',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _navegarPlanos(context);
            },
            icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
            label: const Text('VER PLANOS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaPlanos(
            idAdministradora: idAdministradora,
            emailAdmin: email,
            nomeEmpresa: nome,
            planoAtual: '',
          ),
        ),
      );
    }
  }
}
