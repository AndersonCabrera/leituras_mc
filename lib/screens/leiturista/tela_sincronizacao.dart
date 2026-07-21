import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import '../../services/banco_local.dart';

class TelaSincronizacao extends StatefulWidget {
  const TelaSincronizacao({super.key});

  @override
  State<TelaSincronizacao> createState() => _TelaSincronizacaoState();
}

class _TelaSincronizacaoState extends State<TelaSincronizacao> {
  List<Map<String, dynamic>> filaDeLeituras = [];
  bool sincronizando = false;
  int totalParaSincronizar = 0;

  @override
  void initState() {
    super.initState();
    _carregarFila();
  }

  Future<void> _carregarFila() async {
    final fila = await BancoLocal.lerFila();
    setState(() {
      filaDeLeituras = fila;
      totalParaSincronizar = filaDeLeituras.length;
    });
  }

  Future<void> _enviarParaNuvem() async {
    if (filaDeLeituras.isEmpty) return;
    setState(() {
      sincronizando = true;
    });

    int sucessoCount = 0;

    for (var linha in filaDeLeituras) {
      try {
        int idLocal = linha['id'];
        String itemJson = linha['dados'];
        Map<String, dynamic> dados = jsonDecode(itemJson);
        String? urlFotoFirebase;
        String? caminhoLocal = dados['caminho_foto_local'];

        if (caminhoLocal != null && !caminhoLocal.startsWith('base64:')) {
          io.File arquivoLocal = io.File(caminhoLocal);
          if (await arquivoLocal.exists()) {
            final ref = FirebaseStorage.instance.ref().child(
              'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await ref.putFile(
              arquivoLocal,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            urlFotoFirebase = await ref.getDownloadURL();
            await arquivoLocal.delete();
          }
        } else if (caminhoLocal != null && caminhoLocal.startsWith('base64:')) {
          final Uint8List imageBytes = base64Decode(
            caminhoLocal.replaceAll('base64:', ''),
          );
          final ref = FirebaseStorage.instance.ref().child(
            'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          final tarefa = await ref.putData(
            imageBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          urlFotoFirebase = await tarefa.ref.getDownloadURL();
        }

        DateTime dataLeitura = DateTime.parse(dados['data_hora_string']);
        String mesAno = "${dataLeitura.month}_${dataLeitura.year}";
        String idUnicoDoc =
            "${dados['condominio']}_${dados['apartamento']}_${dados['medidor']}_$mesAno"
                .replaceAll(' ', '_')
                .toLowerCase();

        Map<String, dynamic> pacoteParaNuvem = {
          'condominio': dados['condominio'],
          'apartamento': dados['apartamento'] ?? 'Geral',
          'medidor': dados['medidor'],
          'leitura_anterior': dados['leitura_anterior'],
          'leitura_atual': dados['leitura_atual'],
          'consumo': dados['consumo'],
          'teve_consumo': dados['teve_consumo'],
          'tem_foto_anexada': dados['tem_foto_anexada'],
          'correcao_manual': dados['correcao_manual'] ?? false,
          'data_hora': Timestamp.fromDate(dataLeitura),
        };

        if (urlFotoFirebase != null) {
          pacoteParaNuvem['url_foto'] = urlFotoFirebase;
        }

        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(idUnicoDoc)
            .set(pacoteParaNuvem, SetOptions(merge: true));

        await BancoLocal.remover(idLocal, itemJson);
        sucessoCount++;
      } catch (e) {
        debugPrint("Falha ao sincronizar item: $e");
      }
    }

    await _carregarFila();
    setState(() {
      sincronizando = false;
    });
    if (mounted) {
      if (filaDeLeituras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tudo enviado para a nuvem com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Algumas leituras falharam. Verifique a sua internet.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sincronização',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                totalParaSincronizar == 0
                    ? Icons.cloud_done
                    : Icons.cloud_upload,
                size: 100,
                color: totalParaSincronizar == 0
                    ? Colors.green
                    : Colors.blue.shade800,
              ),
              const SizedBox(height: 20),
              Text(
                totalParaSincronizar == 0
                    ? 'Tudo Sincronizado!'
                    : 'Leituras Pendentes',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tem $totalParaSincronizar leituras prontas para enviar.',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              if (totalParaSincronizar > 0)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: sincronizando
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.sync, color: Colors.white),
                          label: const Text(
                            'Sincronizar Agora',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                          ),
                          onPressed: _enviarParaNuvem,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
