import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TelaCriarAcessoCliente extends StatefulWidget {
  final String idAdministradora;
  final String nomeEmpresa;

  const TelaCriarAcessoCliente({
    super.key,
    required this.idAdministradora,
    required this.nomeEmpresa,
  });

  @override
  State<TelaCriarAcessoCliente> createState() => _TelaCriarAcessoClienteState();
}

class _TelaCriarAcessoClienteState extends State<TelaCriarAcessoCliente> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool salvando = false;

  @override
  void dispose() {
    nomeController.dispose();
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> _salvarAcesso() async {
    if (nomeController.text.isEmpty ||
        emailController.text.isEmpty ||
        senhaController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha todos os campos! Senha mínima de 6 caracteres.',
          ),
        ),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      // Usando uma app secundária para criar conta sem deslogar o Super Admin atual
      FirebaseApp appFantasma = await Firebase.initializeApp(
        name: 'appFantasma_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      UserCredential credencial =
          await FirebaseAuth.instanceFor(
            app: appFantasma,
          ).createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: senhaController.text.trim(),
          );
      await appFantasma.delete();

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credencial.user!.uid)
          .set({
            'nome': nomeController.text.trim(),
            'email': emailController.text.trim(),
            'cargo': 'admin',
            'id_administradora': widget.idAdministradora,
            'data_cadastro': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Acesso criado! Envie este email e senha para o seu cliente.',
            ),
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
          SnackBar(
            content: Text('Erro ao criar acesso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Acesso: ${widget.nomeEmpresa}'),
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
                'Criar Login do Cliente',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Com este acesso, ele terá o próprio painel e não verá os dados de outras empresas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Gestor (Ex: João Silva)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email de Acesso',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha Inicial',
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
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Criar e Liberar Acesso',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                        onPressed: _salvarAcesso,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
