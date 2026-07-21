import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaImportacaoMassa extends StatefulWidget {
  final String idAdministradora;
  const TelaImportacaoMassa({super.key, required this.idAdministradora});

  @override
  State<TelaImportacaoMassa> createState() => _TelaImportacaoMassaState();
}

class _TelaImportacaoMassaState extends State<TelaImportacaoMassa> {
  final TextEditingController _nomePredioCtrl = TextEditingController();
  final TextEditingController _enderecoCtrl = TextEditingController();
  final TextEditingController _apartamentosCtrl = TextEditingController();

  bool _temAgua = true;
  bool _temGas = false;
  bool _temEnergia = false;
  bool _salvando = false;

  @override
  void dispose() {
    _nomePredioCtrl.dispose();
    _enderecoCtrl.dispose();
    _apartamentosCtrl.dispose();
    super.dispose();
  }

  Future<void> _processarImportacao() async {
    if (_nomePredioCtrl.text.trim().isEmpty) {
      _mostrarErro('Digite o nome do Prédio/Condomínio.');
      return;
    }
    if (_apartamentosCtrl.text.trim().isEmpty) {
      _mostrarErro('Cole a lista de apartamentos.');
      return;
    }
    if (!_temAgua && !_temGas && !_temEnergia) {
      _mostrarErro('Selecione pelo menos um tipo de medidor.');
      return;
    }

    setState(() => _salvando = true);

    try {
      List<String> linhasPuras = _apartamentosCtrl.text.split('\n');
      List<String> apartamentosLimpos = [];

      for (String linha in linhasPuras) {
        String limpa = linha.trim();
        if (limpa.isNotEmpty &&
            !limpa.toLowerCase().contains('apartamento') &&
            !limpa.toLowerCase().contains('apto') &&
            !limpa.toLowerCase().contains('unidade')) {
          apartamentosLimpos.add(limpa);
        }
      }

      apartamentosLimpos = apartamentosLimpos.toSet().toList();

      if (apartamentosLimpos.isEmpty) {
        _mostrarErro('Nenhum apartamento válido encontrado.');
        setState(() => _salvando = false);
        return;
      }

      List<String> medidores = [];
      if (_temAgua) medidores.add('agua');
      if (_temGas) medidores.add('gas');
      if (_temEnergia) medidores.add('energia');

      await FirebaseFirestore.instance.collection('predios').add({
        'id_administradora': widget.idAdministradora,
        'nome_predio': _nomePredioCtrl.text.trim().toUpperCase(),
        'endereco': _enderecoCtrl.text.trim(),
        'medidores': medidores,
        'apartamentos': apartamentosLimpos,
        'data_cadastro': FieldValue.serverTimestamp(),
        'lotes_fechados': [],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sucesso! ${apartamentosLimpos.length} unidades importadas para ${_nomePredioCtrl.text.toUpperCase()}.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _mostrarErro('Erro ao processar importação: $e');
      setState(() => _salvando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Importação em Massa',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _salvando
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'A processar e construir banco de dados...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Copie a coluna com o número das unidades no seu Excel e cole na caixa abaixo.',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'DADOS DO PRÉDIO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nomePredioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome do Condomínio (Ex: Edifício Solar)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _enderecoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Endereço (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 25),
                  const Text(
                    'MEDIDORES DO PRÉDIO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Água'),
                          value: _temAgua,
                          onChanged: (v) =>
                              setState(() => _temAgua = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Gás'),
                          value: _temGas,
                          onChanged: (v) =>
                              setState(() => _temGas = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          title: const Text('Energia'),
                          value: _temEnergia,
                          onChanged: (v) =>
                              setState(() => _temEnergia = v ?? false),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),
                  const Text(
                    'COLAR UNIDADES (EXCEL)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _apartamentosCtrl,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      hintText: 'Cole aqui...\n101\n102\n103...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'PROCESSAR IMPORTAÇÃO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _processarImportacao,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
