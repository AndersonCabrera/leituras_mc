import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaAuditoria extends StatelessWidget {
  final String idAdministradora;
  const TelaAuditoria({super.key, required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Auditoria de Anomalias',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Procura leituras que tenham foto anexada (alertas de limite ou correção manual)
        stream: FirebaseFirestore.instance
            .collection('leituras')
            .where('id_administradora', isEqualTo: idAdministradora)
            .where('tem_foto_anexada', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma anomalia para revisar. ✅',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Filtramos em memória para tirar da lista os já aprovados ou rejeitados
          var docsPendentes = snapshot.data!.docs.where((doc) {
            var dados = doc.data() as Map<String, dynamic>;
            return dados['status_auditoria'] != 'aprovado' &&
                dados['status_auditoria'] != 'rejeitada';
          }).toList();

          if (docsPendentes.isEmpty) {
            return const Center(
              child: Text(
                'Todas as anomalias foram auditadas! 🎉',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docsPendentes.length,
            itemBuilder: (context, index) {
              var doc = docsPendentes[index];
              var dados = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (dados['url_foto'] != null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        dados['url_foto'],
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Imagem ainda não sincronizada pelo leiturista.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                image: dados['url_foto'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(dados['url_foto']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: dados['url_foto'] == null
                                  ? const Icon(
                                      Icons.hourglass_bottom_rounded,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${dados['condominio']} - Apto ${dados['apartamento']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Medidor: ${dados['medidor']}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Consumo: ${dados['consumo']?.toStringAsFixed(3)}',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (dados['url_foto'] != null)
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Foto sincronizada',
                                        style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                      ),
                                    ],
                                  )
                                else if (dados['erro_sincronizacao_foto'] == true)
                                  Row(
                                    children: [
                                      Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Erro: ${dados['mensagem_erro'] ?? 'Sincronização falhou'}',
                                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Icon(Icons.hourglass_bottom_rounded, size: 14, color: Colors.orange.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Foto aguardando sincronização',
                                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'REFAZER',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('leituras')
                                  .doc(doc.id)
                                  .update({
                                'status_auditoria': 'rejeitada',
                                'motivo_rejeicao':
                                    'Solicitado refazer pelo gestor',
                                'data_rejeicao':
                                    FieldValue.serverTimestamp(),
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Leitura rejeitada! O apartamento voltou para a lista de pendentes do leiturista.',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'APROVAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('leituras')
                                  .doc(doc.id)
                                  .update({'status_auditoria': 'aprovado'});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Leitura validada e pronta para faturamento!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
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
