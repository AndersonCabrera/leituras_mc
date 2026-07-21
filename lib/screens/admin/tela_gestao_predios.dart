import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaGerenciarEquipes extends StatefulWidget {
  final String idAdministradora;
  const TelaGerenciarEquipes({super.key, required this.idAdministradora});

  @override
  State<TelaGerenciarEquipes> createState() => _TelaGerenciarEquipesState();
}

class _TelaGerenciarEquipesState extends State<TelaGerenciarEquipes> {
  String queryBusca = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gerir Prédios e Equipas',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Procurar Prédio',
                hintText: 'Digite o nome do condomínio...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.blueGrey.shade50,
              ),
              onChanged: (valor) {
                setState(() {
                  queryBusca = valor.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('predios')
                  .where(
                    'id_administradora',
                    isEqualTo: widget.idAdministradora,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(child: Text('Nenhum prédio registado.'));

                var prediosFiltrados = snapshot.data!.docs.where((doc) {
                  var nomePredio =
                      (doc.data() as Map<String, dynamic>)['nome_predio']
                          .toString()
                          .toLowerCase();
                  return nomePredio.contains(queryBusca);
                }).toList();

                if (prediosFiltrados.isEmpty)
                  return const Center(
                    child: Text(
                      'Nenhum condomínio encontrado com esse nome.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: prediosFiltrados.map((doc) {
                    var predio = doc.data() as Map<String, dynamic>;
                    List permitidos =
                        predio.containsKey('leituristas_permitidos')
                        ? predio['leituristas_permitidos']
                        : [];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: const Icon(
                          Icons.apartment,
                          size: 40,
                          color: Colors.blueGrey,
                        ),
                        title: Text(
                          predio['nome_predio'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          '${permitidos.length}/3 Leituristas vinculados',
                          style: TextStyle(
                            color: permitidos.length == 3
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Editar Dados do Prédio',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TelaEditarPredio(
                                      idPredio: doc.id,
                                      dadosPredio: predio,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.people,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Equipa',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade700,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TelaDetalhesPredio(
                                    idPredio: doc.id,
                                    nomePredio: predio['nome_predio'],
                                    idAdministradora: widget.idAdministradora,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TelaCadastroPredio extends StatefulWidget {
  final String idAdministradora;
  const TelaCadastroPredio({super.key, required this.idAdministradora});

  @override
  State<TelaCadastroPredio> createState() => _TelaCadastroPredioState();
}

class _TelaCadastroPredioState extends State<TelaCadastroPredio> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController enderecoController = TextEditingController();
  final TextEditingController apartamentosController = TextEditingController();
  bool medeAgua = false, medeGas = false, medeEnergia = false, salvando = false;

  @override
  void dispose() {
    nomeController.dispose();
    enderecoController.dispose();
    apartamentosController.dispose();
    super.dispose();
  }

  Future<void> _salvarPredio() async {
    if (nomeController.text.isEmpty || apartamentosController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e os apartamentos!')),
      );
      return;
    }
    if (!medeAgua && !medeGas && !medeEnergia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um tipo de medição!'),
        ),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      List<String> tiposMedicao = [];
      if (medeAgua) tiposMedicao.add('agua');
      if (medeGas) tiposMedicao.add('gas');
      if (medeEnergia) tiposMedicao.add('energia');

      List<String> listaApartamentos = apartamentosController.text
          .split(',')
          .map((apto) => apto.trim())
          .where((apto) => apto.isNotEmpty)
          .toList();

      final dadosDoPredio = {
        'nome_predio': nomeController.text.trim(),
        'endereco': enderecoController.text.trim(),
        'id_administradora': widget.idAdministradora,
        'tipos_medicao': tiposMedicao,
        'apartamentos': listaApartamentos,
        'data_cadastro': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('predios').add(dadosDoPredio);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prédio registado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Prédio'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(30),
          child: ListView(
            children: [
              const Text(
                'Dados do Condomínio',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Prédio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: enderecoController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: apartamentosController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Apartamentos (Separe por vírgula)',
                  hintText: 'Ex: 101, 102, 103, 201...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Serviços Medidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Água (m³)'),
                secondary: const Icon(Icons.water_drop, color: Colors.blue),
                value: medeAgua,
                onChanged: (bool? valor) {
                  setState(() {
                    medeAgua = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Gás (m³)'),
                secondary: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                ),
                value: medeGas,
                onChanged: (bool? valor) {
                  setState(() {
                    medeGas = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Energia Elétrica (kWh)'),
                secondary: const Icon(Icons.bolt, color: Colors.yellowAccent),
                value: medeEnergia,
                onChanged: (bool? valor) {
                  setState(() {
                    medeEnergia = valor!;
                  });
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 50,
                child: salvando
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Guardar no Sistema',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                        ),
                        onPressed: _salvarPredio,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaEditarPredio extends StatefulWidget {
  final String idPredio;
  final Map<String, dynamic> dadosPredio;
  const TelaEditarPredio({
    super.key,
    required this.idPredio,
    required this.dadosPredio,
  });

  @override
  State<TelaEditarPredio> createState() => _TelaEditarPredioState();
}

class _TelaEditarPredioState extends State<TelaEditarPredio> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController enderecoController = TextEditingController();
  final TextEditingController apartamentosController = TextEditingController();
  bool medeAgua = false, medeGas = false, medeEnergia = false, salvando = false;

  @override
  void initState() {
    super.initState();
    nomeController.text = widget.dadosPredio['nome_predio'] ?? '';
    enderecoController.text = widget.dadosPredio['endereco'] ?? '';
    List<dynamic> medidores = widget.dadosPredio['tipos_medicao'] ?? [];
    medeAgua = medidores.contains('agua');
    medeGas = medidores.contains('gas');
    medeEnergia = medidores.contains('energia');
    if (widget.dadosPredio.containsKey('apartamentos')) {
      List<dynamic> aptos = widget.dadosPredio['apartamentos'];
      apartamentosController.text = aptos.join(', ');
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    enderecoController.dispose();
    apartamentosController.dispose();
    super.dispose();
  }

  Future<void> _atualizarPredio() async {
    if (nomeController.text.isEmpty || apartamentosController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos obrigatórios!')),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      List<String> tiposMedicao = [];
      if (medeAgua) tiposMedicao.add('agua');
      if (medeGas) tiposMedicao.add('gas');
      if (medeEnergia) tiposMedicao.add('energia');
      List<String> listaApartamentos = apartamentosController.text
          .split(',')
          .map((apto) => apto.trim())
          .where((apto) => apto.isNotEmpty)
          .toList();
      final dadosAtualizados = {
        'nome_predio': nomeController.text.trim(),
        'endereco': enderecoController.text.trim(),
        'tipos_medicao': tiposMedicao,
        'apartamentos': listaApartamentos,
      };

      await FirebaseFirestore.instance
          .collection('predios')
          .doc(widget.idPredio)
          .update(dadosAtualizados);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prédio atualizado!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Prédio'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(30),
          child: ListView(
            children: [
              const Text(
                'Dados do Condomínio',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Prédio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: enderecoController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: apartamentosController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Apartamentos (Separe por vírgula)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Serviços Medidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Água (m³)'),
                secondary: const Icon(Icons.water_drop, color: Colors.blue),
                value: medeAgua,
                onChanged: (bool? valor) {
                  setState(() {
                    medeAgua = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Gás (m³)'),
                secondary: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                ),
                value: medeGas,
                onChanged: (bool? valor) {
                  setState(() {
                    medeGas = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Energia Elétrica (kWh)'),
                secondary: const Icon(Icons.bolt, color: Colors.yellowAccent),
                value: medeEnergia,
                onChanged: (bool? valor) {
                  setState(() {
                    medeEnergia = valor!;
                  });
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 50,
                child: salvando
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Guardar Alterações',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                        ),
                        onPressed: _atualizarPredio,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaDetalhesPredio extends StatefulWidget {
  final String idPredio;
  final String nomePredio;
  final String idAdministradora;
  const TelaDetalhesPredio({
    super.key,
    required this.idPredio,
    required this.nomePredio,
    required this.idAdministradora,
  });

  @override
  State<TelaDetalhesPredio> createState() => _TelaDetalhesPredioState();
}

class _TelaDetalhesPredioState extends State<TelaDetalhesPredio> {
  List<DocumentSnapshot> todosLeituristas = [];
  String? leituristaSelecionado;

  @override
  void initState() {
    super.initState();
    _buscarLeituristasDaEmpresa();
  }

  Future<void> _buscarLeituristasDaEmpresa() async {
    var query = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('id_administradora', isEqualTo: widget.idAdministradora)
        .where('cargo', isEqualTo: 'leiturista')
        .get();
    setState(() {
      todosLeituristas = query.docs;
    });
  }

  Future<void> _adicionarLeiturista(List atuais) async {
    if (leituristaSelecionado == null) return;
    if (atuais.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limite máximo de 3 leituristas atingido!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (atuais.contains(leituristaSelecionado)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este funcionário já está neste roteiro!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    List novaLista = List.from(atuais)..add(leituristaSelecionado);
    await FirebaseFirestore.instance
        .collection('predios')
        .doc(widget.idPredio)
        .update({'leituristas_permitidos': novaLista});
    setState(() {
      leituristaSelecionado = null;
    });
  }

  Future<void> _removerLeiturista(List atuais, String uidRemover) async {
    List novaLista = List.from(atuais)..remove(uidRemover);
    await FirebaseFirestore.instance
        .collection('predios')
        .doc(widget.idPredio)
        .update({'leituristas_permitidos': novaLista});
  }

  String _pegarNomeDoUid(String uid) {
    try {
      return todosLeituristas.firstWhere((doc) => doc.id == uid)['nome'];
    } catch (e) {
      return 'A carregar...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Equipa: ${widget.nomePredio}'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('predios')
            .doc(widget.idPredio)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var predio = snapshot.data!.data() as Map<String, dynamic>;
          List permitidos = predio.containsKey('leituristas_permitidos')
              ? predio['leituristas_permitidos']
              : [];

          return Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Equipa do Roteiro (Máximo: 3)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...permitidos.map((uid) {
                      return Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(
                            _pegarNomeDoUid(uid),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.person_remove,
                              color: Colors.red,
                            ),
                            tooltip: 'Remover',
                            onPressed: () =>
                                _removerLeiturista(permitidos, uid),
                          ),
                        ),
                      );
                    }).toList(),
                    if (permitidos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Nenhum funcionário vinculado.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 20),
                    if (permitidos.length < 3) ...[
                      const Text(
                        'Vincular novo funcionário:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Selecione',
                              ),
                              value: leituristaSelecionado,
                              items: todosLeituristas.map((doc) {
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(doc['nome']),
                                );
                              }).toList(),
                              onChanged: (valor) {
                                setState(() {
                                  leituristaSelecionado = valor;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 55,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'Vincular',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                              ),
                              onPressed: () => _adicionarLeiturista(permitidos),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 30),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Limite atingido para este condomínio.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
