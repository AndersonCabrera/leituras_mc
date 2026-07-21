import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaFechamentoLote extends StatelessWidget {
  final String idAdministradora;
  const TelaFechamentoLote({super.key, required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fechamento de Lote',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('predios')
            .where('id_administradora', isEqualTo: idAdministradora)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum prédio cadastrado ainda.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          DateTime agora = DateTime.now();
          String mesAtual = "${agora.month}_${agora.year}";

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var predio = snapshot.data!.docs[index];
              var dadosPredio = predio.data() as Map<String, dynamic>? ?? {};

              String nomeDoPredio =
                  dadosPredio['nome_predio'] ?? 'Prédio Sem Nome';
              List<dynamic> lotesFechados = dadosPredio['lotes_fechados'] ?? [];
              bool isLoteFechado = lotesFechados.contains(mesAtual);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isLoteFechado
                        ? Colors.red.shade200
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLoteFechado
                          ? Colors.red.shade50
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isLoteFechado ? Icons.lock_rounded : Icons.domain_rounded,
                      color: isLoteFechado
                          ? Colors.red.shade700
                          : Colors.indigo.shade700,
                    ),
                  ),
                  title: Text(
                    nomeDoPredio,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isLoteFechado
                          ? 'O lote de leitura deste mês já está encerrado.'
                          : 'Bloquear edições de leitura neste mês.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isLoteFechado
                            ? Colors.red.shade600
                            : Colors.grey.shade700,
                        fontWeight: isLoteFechado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),

                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLoteFechado
                          ? Colors.grey.shade300
                          : Colors.indigo.shade600,
                      foregroundColor: isLoteFechado
                          ? Colors.grey.shade600
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: isLoteFechado ? 0 : 2,
                    ),
                    icon: Icon(
                      isLoteFechado ? Icons.lock : Icons.lock_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isLoteFechado ? 'FECHADO' : 'FECHAR',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: isLoteFechado
                        ? null
                        : () async {
                            bool confirmacao =
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar Fechamento'),
                                    content: Text(
                                      'Tem certeza que deseja fechar o lote de $nomeDoPredio?\n\nOs leituristas não poderão mais enviar ou editar leituras neste mês.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('CANCELAR'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'SIM, FECHAR LOTE',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (confirmacao) {
                              try {
                                await FirebaseFirestore.instance
                                    .collection('predios')
                                    .doc(predio.id)
                                    .set({
                                      'lotes_fechados': FieldValue.arrayUnion([
                                        mesAtual,
                                      ]),
                                    }, SetOptions(merge: true));

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Lote bloqueado com sucesso! Nenhuma leitura será alterada.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Erro ao bloquear lote: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                              }
                            }
                          },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
