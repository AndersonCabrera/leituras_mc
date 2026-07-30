import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/plano.dart';

class TelaListaEquipe extends StatelessWidget {
  final String idAdministradora;
  const TelaListaEquipe({super.key, required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Equipe Registada',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('id_administradora', isEqualTo: idAdministradora)
            .where('cargo', isEqualTo: 'leiturista')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off_rounded,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Nenhum leiturista na equipa.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          var equipe = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: equipe.length,
            itemBuilder: (context, index) {
              var leiturista = equipe[index].data() as Map<String, dynamic>;
              String nome = leiturista['nome'] ?? 'Sem nome';
              String inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      inicial,
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(leiturista['email'] ?? 'Sem email'),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('id_administradora', isEqualTo: idAdministradora)
            .where('cargo', isEqualTo: 'leiturista')
            .snapshots(),
        builder: (context, snapshotLeit) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('administradoras')
                .doc(idAdministradora)
                .get(),
            builder: (context, snapshotAdm) {
              var dadosAdm = snapshotAdm.data?.data() as Map<String, dynamic>?;
              var planoId = dadosAdm?['plano'] ?? 'gratis';
              var plano = Plano.fromId(planoId);
              var qtdAtual = snapshotLeit.data?.docs.length ?? 0;
              var atingiuLimite = !plano.ilimitadoLeituristas && qtdAtual >= plano.limiteLeituristas;

              return FloatingActionButton.extended(
                backgroundColor: atingiuLimite ? Colors.grey : Colors.green.shade700,
                onPressed: () {
                  if (atingiuLimite) {
                    _mostrarLimiteAtingido(context);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TelaCadastroLeiturista(idAdministradora: idAdministradora),
                    ),
                  );
                },
                icon: Icon(
                  atingiuLimite ? Icons.lock_rounded : Icons.person_add_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  atingiuLimite ? 'Limite do Plano' : 'Novo Leiturista',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarLimiteAtingido(BuildContext context) {
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
          'Você atingiu o limite de leituristas do seu plano atual. '
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

class TelaCadastroLeiturista extends StatefulWidget {
  final String idAdministradora;
  const TelaCadastroLeiturista({super.key, required this.idAdministradora});

  @override
  State<TelaCadastroLeiturista> createState() => _TelaCadastroLeituristaState();
}

class _TelaCadastroLeituristaState extends State<TelaCadastroLeiturista> {
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

  Future<void> _salvarFuncionario() async {
    if (nomeController.text.isEmpty ||
        emailController.text.isEmpty ||
        senhaController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha todos os campos! A senha deve ter no mínimo 6 letras/números.',
          ),
        ),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
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
            'cargo': 'leiturista',
            'id_administradora': widget.idAdministradora,
            'data_cadastro': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funcionário registado e pronto para trabalhar!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no acesso: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
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
        title: const Text('Novo Leiturista'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dados do Funcionário',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Utilizará este email e senha para aceder à aplicação móvel.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email de Acesso',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha (mínimo 6 caracteres)',
                    prefixIcon: Icon(Icons.lock),
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
                            'Criar Acesso',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                          ),
                          onPressed: _salvarFuncionario,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
