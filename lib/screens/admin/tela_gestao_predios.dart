import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/plano.dart';

// TELA PRINCIPAL DE LISTAGEM
class TelaGestaoPredios extends StatelessWidget {
  final String adminId;
  const TelaGestaoPredios({Key? key, required this.adminId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Gestão de Prédios'),
        backgroundColor: isDark
            ? theme.colorScheme.surface
            : const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('predios')
            .where('admin_id', isEqualTo: adminId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhum prédio cadastrado.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Recupera o limite customizado ou usa 1.0 como padrão
              double limite = (data['limite_consumo_alerta'] ?? 1.0).toDouble();

              return Card(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : Colors.blue.shade100,
                    child: Icon(
                      Icons.location_city,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    data['nome'] ?? 'Sem nome',
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                  ),
                  subtitle: Text(
                    'Limite para foto: $limite m³\nEquipe: ${data['equipe_id'] ?? 'Não vinculada'}',
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TelaEditarPredio(
                            predioId: doc.id,
                            predioData: data,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('predios')
            .where('admin_id', isEqualTo: adminId)
            .snapshots(),
        builder: (context, snapshotPredios) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('administradoras')
                .doc(adminId)
                .get(),
            builder: (context, snapshotAdm) {
              var dadosAdm = snapshotAdm.data?.data() as Map<String, dynamic>?;
              var planoId = dadosAdm?['plano'] ?? 'gratis';
              var plano = Plano.fromId(planoId);
              var qtdAtual = snapshotPredios.data?.docs.length ?? 0;
              var atingiuLimite = !plano.ilimitadoCondominios && qtdAtual >= plano.limiteCondominios;

              return FloatingActionButton.extended(
                backgroundColor: atingiuLimite ? Colors.grey : theme.colorScheme.primary,
                onPressed: () {
                  if (atingiuLimite) {
                    _mostrarLimiteAtingido(context, plano.nome, 'condomínios');
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaCadastroPredio(adminId: adminId),
                    ),
                  );
                },
                icon: Icon(atingiuLimite ? Icons.lock_rounded : Icons.add, color: Colors.white),
                label: Text(
                  atingiuLimite ? 'Limite do Plano' : 'Novo Prédio',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarLimiteAtingido(
      BuildContext context, String planoNome, String recurso) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Limite Atingido', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Você atingiu o limite de condomínios do seu plano atual. '
          'Faça um upgrade para cadastrar mais.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// TELA DE CADASTRO
class TelaCadastroPredio extends StatefulWidget {
  final String adminId;
  const TelaCadastroPredio({Key? key, required this.adminId}) : super(key: key);

  @override
  State<TelaCadastroPredio> createState() => _TelaCadastroPredioState();
}

class _TelaCadastroPredioState extends State<TelaCadastroPredio> {
  final _nomeCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _limiteConsumoCtrl = TextEditingController(text: '1.0'); // Padrão 1.0
  bool _isLoading = false;

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _enderecoCtrl.dispose();
    _limiteConsumoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarPredio() async {
    if (_nomeCtrl.text.isEmpty) return;

    setState(() => _isLoading = true);

    // Tratamento seguro para garantir que vira número
    double limite =
        double.tryParse(_limiteConsumoCtrl.text.replaceAll(',', '.')) ?? 1.0;

    await FirebaseFirestore.instance.collection('predios').add({
      'admin_id': widget.adminId,
      'nome': _nomeCtrl.text,
      'endereco': _enderecoCtrl.text,
      'limite_consumo_alerta': limite, // NOVO CAMPO SALVO NO BANCO
      'data_cadastro': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Prédio')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Prédio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _enderecoCtrl,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limiteConsumoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Limite de Consumo para exigir Foto (m³)',
                border: OutlineInputBorder(),
                helperText: 'Ex: 1.0 para residenciais, 5.0 para comerciais',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _salvarPredio,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Salvar Prédio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// TELA DE EDIÇÃO
class TelaEditarPredio extends StatefulWidget {
  final String predioId;
  final Map<String, dynamic> predioData;
  const TelaEditarPredio({
    Key? key,
    required this.predioId,
    required this.predioData,
  }) : super(key: key);

  @override
  State<TelaEditarPredio> createState() => _TelaEditarPredioState();
}

class _TelaEditarPredioState extends State<TelaEditarPredio> {
  late TextEditingController _nomeCtrl;
  late TextEditingController _enderecoCtrl;
  late TextEditingController _limiteConsumoCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.predioData['nome'] ?? '');
    _enderecoCtrl = TextEditingController(
      text: widget.predioData['endereco'] ?? '',
    );

    // Carrega o limite ou 1.0 se não existir
    double limite = (widget.predioData['limite_consumo_alerta'] ?? 1.0)
        .toDouble();
    _limiteConsumoCtrl = TextEditingController(text: limite.toString());
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _enderecoCtrl.dispose();
    _limiteConsumoCtrl.dispose();
    super.dispose();
  }

  Future<void> _atualizarPredio() async {
    setState(() => _isLoading = true);

    double limite =
        double.tryParse(_limiteConsumoCtrl.text.replaceAll(',', '.')) ?? 1.0;

    await FirebaseFirestore.instance
        .collection('predios')
        .doc(widget.predioId)
        .update({
          'nome': _nomeCtrl.text,
          'endereco': _enderecoCtrl.text,
          'limite_consumo_alerta': limite,
        });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Prédio')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Prédio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _enderecoCtrl,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limiteConsumoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Limite de Consumo para exigir Foto (m³)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _atualizarPredio,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Atualizar Prédio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
