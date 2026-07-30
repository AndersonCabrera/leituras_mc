import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/tela_admin_dashboard.dart';
import '../../core/theme.dart';

class TelaRegistroAdmin extends StatefulWidget {
  const TelaRegistroAdmin({super.key});

  @override
  State<TelaRegistroAdmin> createState() => _TelaRegistroAdminState();
}

class _TelaRegistroAdminState extends State<TelaRegistroAdmin> {
  final _nomeEmpresaController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _nomeGestorController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;

  @override
  void dispose() {
    _nomeEmpresaController.dispose();
    _cnpjController.dispose();
    _nomeGestorController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (_nomeEmpresaController.text.trim().isEmpty ||
        _nomeGestorController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _senhaController.text.isEmpty) {
      _mostrarErro('Preencha todos os campos obrigatórios.');
      return;
    }
    if (_senhaController.text.length < 6) {
      _mostrarErro('A senha deve ter no mínimo 6 caracteres.');
      return;
    }
    if (_senhaController.text != _confirmarSenhaController.text) {
      _mostrarErro('As senhas não conferem.');
      return;
    }

    setState(() => _carregando = true);

    try {
      String cnpj = _cnpjController.text.trim();

      if (cnpj.isNotEmpty) {
        var existente = await FirebaseFirestore.instance
            .collection('administradoras')
            .where('cnpj', isEqualTo: cnpj)
            .limit(1)
            .get();
        if (existente.docs.isNotEmpty) {
          _mostrarErro('Já existe uma empresa cadastrada com este CNPJ.');
          setState(() => _carregando = false);
          return;
        }
      }

      UserCredential credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _senhaController.text,
          );

      String uid = credencial.user!.uid;

      var administradoraRef = await FirebaseFirestore.instance
          .collection('administradoras')
          .add({
            'nome_empresa': _nomeEmpresaController.text.trim(),
            'cnpj': cnpj,
            'nome_gestor': _nomeGestorController.text.trim(),
            'email': _emailController.text.trim(),
            'plano': 'gratis',
            'status_assinatura': 'trial',
            'data_cadastro': FieldValue.serverTimestamp(),
            'data_inicio_trial': FieldValue.serverTimestamp(),
            'data_fim_trial': DateTime.now().add(const Duration(days: 60)),
          });

      String idAdmin = administradoraRef.id;

      await FirebaseFirestore.instance
          .collection('assinaturas')
          .doc(idAdmin)
          .set({
            'id_administradora': idAdmin,
            'plano': 'gratis',
            'status': 'trial',
            'data_inicio_trial': FieldValue.serverTimestamp(),
            'data_fim_trial': DateTime.now().add(const Duration(days: 60)),
          });

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nome': _nomeGestorController.text.trim(),
        'email': _emailController.text.trim(),
        'cargo': 'admin',
        'id_administradora': idAdmin,
        'data_cadastro': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TelaAdminDashboard(idAdministradora: idAdmin),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Erro ao criar conta.';
      if (e.code == 'email-already-in-use') {
        msg = 'Este email já está em uso.';
      }
      _mostrarErro(msg);
      setState(() => _carregando = false);
    } catch (e) {
      _mostrarErro('Erro: $e');
      setState(() => _carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [BotaoTrocaTema(), SizedBox(width: 10)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 80),
                const SizedBox(height: 12),
                const Text(
                  'Criar Conta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Comece seu trial gratuito de 60 dias',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nomeEmpresaController,
                  decoration: _inputDec(
                    label: 'Nome da Empresa',
                    icon: Icons.business,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _cnpjController,
                  decoration: _inputDec(
                    label: 'CNPJ (opcional)',
                    icon: Icons.credit_card,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nomeGestorController,
                  decoration: _inputDec(
                    label: 'Seu Nome',
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDec(
                    label: 'E-mail',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _senhaController,
                  obscureText: _ocultarSenha,
                  decoration: _inputDec(
                    label: 'Senha',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _ocultarSenha
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () =>
                          setState(() => _ocultarSenha = !_ocultarSenha),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _confirmarSenhaController,
                  obscureText: _ocultarConfirmacao,
                  decoration: _inputDec(
                    label: 'Confirmar Senha',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _ocultarConfirmacao
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(
                          () => _ocultarConfirmacao = !_ocultarConfirmacao),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _carregando ? null : _cadastrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _carregando
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Criar Conta e Iniciar Trial',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Já tem uma conta? Faça login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
