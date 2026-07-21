import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaCadastroAdministradora extends StatefulWidget {
  const TelaCadastroAdministradora({super.key});

  @override
  State<TelaCadastroAdministradora> createState() =>
      _TelaCadastroAdministradoraState();
}

class _TelaCadastroAdministradoraState
    extends State<TelaCadastroAdministradora> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cnpjController = TextEditingController();
  bool salvando = false;

  @override
  void dispose() {
    nomeController.dispose();
    cnpjController.dispose();
    super.dispose();
  }

  Future<void> _salvarCliente() async {
    if (nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome da empresa é obrigatório!')),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      await FirebaseFirestore.instance.collection('administradoras').add({
        'nome_empresa': nomeController.text.trim(),
        'cnpj': cnpjController.text.trim(),
        'data_cadastro': FieldValue.serverTimestamp(),
        'status': 'ativo',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente cadastrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Cliente'),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Dados da Administradora',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Empresa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: cnpjController,
                decoration: const InputDecoration(
                  labelText: 'CNPJ (Opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: salvando
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Salvar Empresa',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                        ),
                        onPressed: _salvarCliente,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
