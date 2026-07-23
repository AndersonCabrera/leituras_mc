import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../leiturista/tela_condominios.dart';
import '../admin/tela_admin_dashboard.dart';
import '../super_admin/tela_super_admin_dashboard.dart';
import '../../core/theme.dart';
import '../../services/notificacao_service.dart';

class EcraLogin extends StatefulWidget {
  const EcraLogin({super.key});

  @override
  State<EcraLogin> createState() => _EcraLoginState();
}

class _EcraLoginState extends State<EcraLogin> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool carregando = false;
  bool _ocultarSenha = true;

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (emailController.text.isEmpty || senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha email e senha!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      UserCredential credencial = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: senhaController.text.trim(),
          );

      if (credencial.user != null) {
        DocumentSnapshot fichaUsuario = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(credencial.user!.uid)
            .get();

        if (fichaUsuario.exists) {
          String cargo = fichaUsuario.get('cargo');
          String? idAdmin =
              fichaUsuario.data().toString().contains('id_administradora')
              ? fichaUsuario.get('id_administradora')
              : null;

          // 💡 CORRIGIDO: Passamos a idAdmin e o cargo para o serviço de push
          await NotificacaoService.salvarTokenNoBanco(
            credencial.user!.uid,
            idAdmin ?? '',
            cargo,
          );

          if (cargo == 'leiturista' && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TelaCondominios(idAdministradora: idAdmin!),
              ),
            );
          } else if (cargo == 'admin' && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TelaAdminDashboard(idAdministradora: idAdmin!),
              ),
            );
          } else if (cargo == 'super_admin' && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TelaSuperAdminDashboard(),
              ),
            );
          }
        } else {
          await FirebaseAuth.instance.signOut();
          setState(() {
            carregando = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro: Usuário sem cadastro de cargo.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        carregando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no login: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        carregando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar dados: $e'),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: const [BotaoTrocaTema(), SizedBox(width: 10)],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 20),
              const Text(
                'Leituras MC',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const Text(
                'Acesso ao Sistema',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: senhaController,
                obscureText: _ocultarSenha,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarSenha ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _ocultarSenha = !_ocultarSenha;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: carregando ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: carregando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Entrar',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
