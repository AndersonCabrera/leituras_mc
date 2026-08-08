import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: 'Vincular Prédios Órfãos',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaVincularPredios(adminId: adminId),
                ),
              );
            },
          ),
        ],
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    size: 80,
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum prédio vinculado.',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seus prédios foram importados pelo super admin?\nUse o botão de vínculo no canto superior.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TelaFormularioPredio(adminId: adminId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      'Cadastrar Prédio',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              // Recupera o limite customizado ou usa 1.0 como padrão.
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
                    'Limite para foto: ${limite.toStringAsFixed(1)} m³\nEquipe: ${data['leiturista_nome'] ?? 'Não vinculada'}',
                    style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TelaFormularioPredio(
                            predioId: doc.id,
                            predioData: data,
                            adminId: adminId, // Passando o adminId
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

              // ✅ EXCEÇÃO: Remove a trava de limite para o perfil específico.
              bool eAdminMaster =
                  dadosAdm?['email'] == 'cabrera@leiturasmc.com';

              var atingiuLimite = eAdminMaster
                  ? false
                  : !plano.ilimitadoCondominios &&
                        qtdAtual >= plano.limiteCondominios;

              return FloatingActionButton.extended(
                backgroundColor: atingiuLimite
                    ? Colors.grey
                    : theme.colorScheme.primary,
                onPressed: () {
                  if (atingiuLimite) {
                    _mostrarLimiteAtingido(context, plano.nome, 'condomínios');
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaFormularioPredio(adminId: adminId),
                    ),
                  );
                },
                icon: Icon(
                  atingiuLimite ? Icons.lock_rounded : Icons.add,
                  color: Colors.white,
                ),
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
    BuildContext context,
    String planoNome,
    String recurso,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text(
              'Limite Atingido',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// TELA UNIFICADA DE CADASTRO E EDIÇÃO
class TelaFormularioPredio extends StatefulWidget {
  final String adminId;
  final String? predioId;
  final Map<String, dynamic>? predioData;

  const TelaFormularioPredio({
    Key? key,
    required this.adminId,
    this.predioId,
    this.predioData,
  }) : super(key: key);

  @override
  State<TelaFormularioPredio> createState() => _TelaFormularioPredioState();
}

class _TelaFormularioPredioState extends State<TelaFormularioPredio> {
  final _nomeCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _cnpjCtrl = TextEditingController();
  final _limiteConsumoCtrl = TextEditingController(text: '1.0'); // Padrão 1.0

  bool _temAgua = true;
  bool _temGas = false;
  bool _temEletricidade = false;

  List<String> _apartamentos = [];
  final _apartamentoCtrl = TextEditingController();

  bool _isLoading = false;
  bool get _isEditing => widget.predioId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.predioData != null) {
      _nomeCtrl.text = widget.predioData!['nome'] ?? '';
      _enderecoCtrl.text = widget.predioData!['endereco'] ?? '';
      _cnpjCtrl.text = widget.predioData!['cnpj'] ?? '';
      _limiteConsumoCtrl.text =
          (widget.predioData!['limite_consumo_alerta'] ?? 1.0).toString();

      _temAgua = widget.predioData!['tem_medidor_agua'] ?? true;
      _temGas = widget.predioData!['tem_medidor_gas'] ?? false;
      _temEletricidade =
          widget.predioData!['tem_medidor_eletricidade'] ?? false;

      _carregarApartamentos();
    }
  }

  Future<void> _carregarApartamentos() async {
    if (!_isEditing) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('predios')
        .doc(widget.predioId!)
        .collection('apartamentos')
        .get();
    if (mounted) {
      setState(() {
        _apartamentos = snapshot.docs.map((doc) => doc.id).toList()..sort();
      });
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _enderecoCtrl.dispose();
    _cnpjCtrl.dispose();
    _limiteConsumoCtrl.dispose();
    _apartamentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvarFormulario() async {
    if (_nomeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O nome do prédio é obrigatório.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      double limite =
          double.tryParse(_limiteConsumoCtrl.text.replaceAll(',', '.')) ?? 1.0;

      final dadosPredio = {
        'admin_id': widget.adminId,
        'nome': _nomeCtrl.text.trim(),
        'endereco': _enderecoCtrl.text.trim(),
        'cnpj': _cnpjCtrl.text.trim(),
        'limite_consumo_alerta': limite,
        'tem_medidor_agua': _temAgua,
        'tem_medidor_gas': _temGas,
        'tem_medidor_eletricidade': _temEletricidade,
        'data_cadastro': _isEditing
            ? widget.predioData!['data_cadastro']
            : FieldValue.serverTimestamp(),
        'ultima_atualizacao': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        // MODO EDIÇÃO
        final predioRef = FirebaseFirestore.instance
            .collection('predios')
            .doc(widget.predioId!);
        await predioRef.update(dadosPredio);
        // AQUI IRIA A LÓGICA PARA ATUALIZAR APARTAMENTOS (se necessário)
      } else {
        // MODO CADASTRO
        final predioRef = await FirebaseFirestore.instance
            .collection('predios')
            .add(dadosPredio);

        if (_apartamentos.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final ap in _apartamentos) {
            final apRef = predioRef.collection('apartamentos').doc(ap);
            batch.set(apRef, {
              'nome': ap,
              'data_cadastro': FieldValue.serverTimestamp(),
            });
          }
          await batch.commit();
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prédio salvo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Prédio' : 'Cadastrar Novo Prédio'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded),
              tooltip: 'Excluir Prédio',
              onPressed: _excluirPredio,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dados Principais',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do Prédio',
                prefixIcon: Icon(Icons.apartment_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cnpjCtrl,
              decoration: const InputDecoration(
                labelText: 'CNPJ',
                prefixIcon: Icon(Icons.business_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _enderecoCtrl,
              decoration: const InputDecoration(
                labelText: 'Endereço',
                prefixIcon: Icon(Icons.location_on_outlined),
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
                prefixIcon: Icon(Icons.warning_amber_rounded),
                border: OutlineInputBorder(),
                helperText: 'Ex: 1.0 para residenciais, 5.0 para comerciais',
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tipos de Medidores no Prédio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            CheckboxListTile(
              title: const Text('Água'),
              value: _temAgua,
              onChanged: (val) => setState(() => _temAgua = val!),
            ),
            CheckboxListTile(
              title: const Text('Gás'),
              value: _temGas,
              onChanged: (val) => setState(() => _temGas = val!),
            ),
            CheckboxListTile(
              title: const Text('Eletricidade'),
              value: _temEletricidade,
              onChanged: (val) => setState(() => _temEletricidade = val!),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Apartamentos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Importar'),
                  onPressed: _mostrarDialogoImportacao,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!_isEditing) _buildGerenciadorApartamentos(),
            if (_isEditing)
              const Text(
                'A gestão de apartamentos (adicionar/remover) deve ser feita em uma ferramenta dedicada para evitar inconsistências com leituras existentes.',
                style: TextStyle(color: Colors.grey),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _salvarFormulario,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_isEditing ? 'Atualizar Prédio' : 'Salvar Prédio'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGerenciadorApartamentos() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apartamentoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nº ou Nome do Apartamento',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () {
                  final ap = _apartamentoCtrl.text.trim();
                  if (ap.isNotEmpty && !_apartamentos.contains(ap)) {
                    setState(() {
                      _apartamentos.add(ap);
                      _apartamentos.sort();
                      _apartamentoCtrl.clear();
                    });
                  }
                },
              ),
            ],
          ),
          const Divider(),
          _apartamentos.isEmpty
              ? const Text('Nenhum apartamento adicionado')
              : Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _apartamentos
                      .map(
                        (ap) => Chip(
                          label: Text(ap),
                          onDeleted: () {
                            setState(() {
                              _apartamentos.remove(ap);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }

  void _mostrarDialogoImportacao() {
    final importCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar Apartamentos'),
        content: TextField(
          controller: importCtrl,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Cole a lista de apartamentos aqui (um por linha)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final linhas = importCtrl.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty);
              setState(() {
                _apartamentos.addAll(linhas);
                // Remove duplicados e ordena
                _apartamentos = _apartamentos.toSet().toList()..sort();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirPredio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text(
          'Esta ação é irreversível e irá apagar o prédio e TODOS os seus apartamentos. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        // Excluir subcoleção de apartamentos
        final apartamentos = await FirebaseFirestore.instance
            .collection('predios')
            .doc(widget.predioId!)
            .collection('apartamentos')
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in apartamentos.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Excluir o prédio
        await FirebaseFirestore.instance
            .collection('predios')
            .doc(widget.predioId!)
            .delete();

        if (mounted) {
          Navigator.of(context).pop(); // Fecha a tela de edição
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
}

// TELA DE VINCULAR PRÉDIOS ÓRFÃOS
class TelaVincularPredios extends StatefulWidget {
  final String adminId;
  const TelaVincularPredios({Key? key, required this.adminId})
    : super(key: key);

  @override
  State<TelaVincularPredios> createState() => _TelaVincularPrediosState();
}

class _TelaVincularPrediosState extends State<TelaVincularPredios> {
  bool _processando = false;
  List<Map<String, dynamic>> _prediosOrfaos = [];
  List<String> _selecionados = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _buscarPrediosOrfaos();
  }

  Future<void> _buscarPrediosOrfaos() async {
    setState(() {
      _carregando = true;
      _prediosOrfaos = [];
    });

    try {
      // Buscar prédios cujo admin_id NÃO é desta administradora
      // Primeiro: prédios sem admin_id
      var semAdmin = await FirebaseFirestore.instance
          .collection('predios')
          .where('admin_id', isEqualTo: '')
          .get();

      for (var doc in semAdmin.docs) {
        var data = doc.data();
        _prediosOrfaos.add({
          'id': doc.id,
          'nome': data['nome'] ?? 'Sem nome',
          'endereco': data['endereco'] ?? '',
        });
      }

      // Buscar também prédios onde admin_id não existe (campo ausente)
      var todosPredios = await FirebaseFirestore.instance
          .collection('predios')
          .limit(500)
          .get();

      for (var doc in todosPredios.docs) {
        var data = doc.data();
        if (!data.containsKey('admin_id') || data['admin_id'] == null) {
          // Evitar duplicatas
          if (!_prediosOrfaos.any((p) => p['id'] == doc.id)) {
            _prediosOrfaos.add({
              'id': doc.id,
              'nome': data['nome'] ?? 'Sem nome',
              'endereco': data['endereco'] ?? '',
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Erro ao buscar prédios órfãos: $e");
    }

    setState(() => _carregando = false);
  }

  Future<void> _vincularSelecionados() async {
    if (_selecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um prédio para vincular.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _processando = true);

    try {
      for (var predioId in _selecionados) {
        await FirebaseFirestore.instance
            .collection('predios')
            .doc(predioId)
            .update({'admin_id': widget.adminId});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selecionados.length} prédio(s) vinculado(s) com sucesso!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao vincular: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _processando = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Vincular Prédios'),
        backgroundColor: isDark
            ? theme.colorScheme.surface
            : const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          if (_selecionados.isNotEmpty)
            TextButton.icon(
              onPressed: _processando ? null : _vincularSelecionados,
              icon: _processando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.link_rounded, color: Colors.white),
              label: Text(
                'Vincular (${_selecionados.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _prediosOrfaos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: Colors.green.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum prédio órfão encontrado.',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos os prédios já estão vinculados.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Prédios sem administradora. Selecione os que são seus.',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _prediosOrfaos.length,
                    itemBuilder: (context, index) {
                      var predio = _prediosOrfaos[index];
                      bool selecionado = _selecionados.contains(predio['id']);

                      return Card(
                        color: isDark
                            ? theme.colorScheme.surface
                            : Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: selecionado,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selecionados.add(predio['id']);
                              } else {
                                _selecionados.remove(predio['id']);
                              }
                            });
                          },
                          title: Text(
                            predio['nome'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          subtitle: Text(
                            predio['endereco'].isNotEmpty
                                ? predio['endereco']
                                : 'Sem endereço',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          secondary: Icon(
                            Icons.apartment_rounded,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
