import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';

import '../../models/plano.dart';

class TelaListaEquipe extends StatelessWidget {
  final String idAdministradora;
  const TelaListaEquipe({Key? key, required this.idAdministradora})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    const String vercelApiUrl =
        'https://leituras-mc.vercel.app/api/excluirUsuario';

    Future<void> excluirLeiturista(String userId, String userName) async {
      bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar Exclusao'),
          content: Text(
            'Tem certeza que deseja excluir o leiturista $userName? Esta acao nao pode ser desfeita.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            TextButton(
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      try {
        final response = await http.post(
          Uri.parse(vercelApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userId': userId}),
        );

        if (response.statusCode != 200 && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir: ${response.body}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint("Erro ao excluir leiturista: $e");
      }
    }

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }
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
              var leituristaId = equipe[index].id;
              String nome = leiturista['nome'] ?? 'Sem nome';
              String inicial =
                  nome.isNotEmpty ? nome[0].toUpperCase() : '?';
              String email = leiturista['email'] ?? 'Sem email';
              String cpf = leiturista['cpf'] ?? '';

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
                  subtitle: Text(
                    cpf.isNotEmpty ? 'CPF: $cpf' : email,
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'excluir') {
                        excluirLeiturista(leituristaId, nome);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'excluir',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_forever,
                            color: Colors.red,
                          ),
                          title: Text(
                            'Excluir',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                    icon:
                        const Icon(Icons.more_vert, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TelaDetalhesLeiturista(
                          leituristaId: leituristaId,
                          leituristaData: leiturista,
                        ),
                      ),
                    );
                  },
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
              var dadosAdm =
                  snapshotAdm.data?.data() as Map<String, dynamic>?;
              var planoId = dadosAdm?['plano'] ?? 'gratis';
              var plano = Plano.fromId(planoId);
              var qtdAtual = snapshotLeit.data?.docs.length ?? 0;
              var atingiuLimite = !plano.ilimitadoLeituristas &&
                  qtdAtual >= plano.limiteLeituristas;

              return FloatingActionButton.extended(
                backgroundColor:
                    atingiuLimite ? Colors.grey : Colors.green.shade700,
                onPressed: () {
                  if (atingiuLimite) {
                    _mostrarLimiteAtingido(context);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TelaCadastroLeiturista(
                        idAdministradora: idAdministradora,
                      ),
                    ),
                  );
                },
                icon: Icon(
                  atingiuLimite
                      ? Icons.lock_rounded
                      : Icons.person_add_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  atingiuLimite ? 'Limite do Plano' : 'Novo Leiturista',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          'Voce atingiu o limite de leituristas do seu plano atual. '
          'Faca um upgrade para cadastrar mais.',
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

// TELA DE DETALHES DO LEITURISTA
class TelaDetalhesLeiturista extends StatelessWidget {
  final String leituristaId;
  final Map<String, dynamic> leituristaData;

  const TelaDetalhesLeiturista({
    super.key,
    required this.leituristaId,
    required this.leituristaData,
  });

  @override
  Widget build(BuildContext context) {
    String nome = leituristaData['nome'] ?? 'Sem nome';
    String email = leituristaData['email'] ?? 'Sem email';
    String cpf = leituristaData['cpf'] ?? 'Nao informado';
    String telefone = leituristaData['telefone'] ?? 'Nao informado';
    String inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detalhes do Leiturista',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.green.shade100,
              child: Text(
                inicial,
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              nome,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildInfoCard(
              icon: Icons.person,
              label: 'Nome Completo',
              value: nome,
            ),
            _buildInfoCard(
              icon: Icons.email,
              label: 'Email',
              value: email,
            ),
            _buildInfoCard(
              icon: Icons.badge,
              label: 'CPF',
              value: cpf,
            ),
            _buildInfoCard(
              icon: Icons.phone,
              label: 'Telefone',
              value: telefone,
            ),
            _buildInfoCard(
              icon: Icons.calendar_today,
              label: 'Data de Cadastro',
              value: leituristaData['data_cadastro'] != null
                  ? (leituristaData['data_cadastro'] as Timestamp)
                      .toDate()
                      .toString()
                      .substring(0, 10)
                  : 'Nao disponivel',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey.shade700),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// TELA DE CADASTRO DE LEITURISTA
class TelaCadastroLeiturista extends StatefulWidget {
  final String idAdministradora;
  const TelaCadastroLeiturista({super.key, required this.idAdministradora});

  @override
  State<TelaCadastroLeiturista> createState() =>
      _TelaCadastroLeituristaState();
}

class _TelaCadastroLeituristaState extends State<TelaCadastroLeiturista> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _sobrenomeController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _sobrenomeController.dispose();
    _cpfController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  String _formatarCPF(String value) {
    value = value.replaceAll(RegExp(r'[^\d]'), '');
    if (value.length > 11) value = value.substring(0, 11);
    if (value.length > 9) {
      return '${value.substring(0, 3)}.${value.substring(3, 6)}.${value.substring(6, 9)}-${value.substring(9)}';
    } else if (value.length > 6) {
      return '${value.substring(0, 3)}.${value.substring(3, 6)}.${value.substring(6)}';
    } else if (value.length > 3) {
      return '${value.substring(0, 3)}.${value.substring(3)}';
    }
    return value;
  }

  String _formatarTelefone(String value) {
    value = value.replaceAll(RegExp(r'[^\d]'), '');
    if (value.length > 11) value = value.substring(0, 11);
    if (value.length > 10) {
      return '(${value.substring(0, 2)}) ${value.substring(2, 7)}-${value.substring(7)}';
    } else if (value.length > 6) {
      return '(${value.substring(0, 2)}) ${value.substring(2, 6)}-${value.substring(6)}';
    } else if (value.length > 2) {
      return '(${value.substring(0, 2)}) ${value.substring(2)}';
    }
    return value;
  }

  bool _validarCPF(String cpf) {
    cpf = cpf.replaceAll(RegExp(r'[^\d]'), '');
    if (cpf.length != 11) return false;
    if (cpf == '00000000000' ||
        cpf == '11111111111' ||
        cpf == '22222222222' ||
        cpf == '33333333333' ||
        cpf == '44444444444' ||
        cpf == '55555555555' ||
        cpf == '66666666666' ||
        cpf == '77777777777' ||
        cpf == '88888888888' ||
        cpf == '99999999999') return false;

    // Validacao dos digitos verificadores
    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += int.parse(cpf[i]) * (10 - i);
    }
    int resto = 11 - (soma % 11);
    if (resto == 10 || resto == 11) resto = 0;
    if (resto != int.parse(cpf[9])) return false;

    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += int.parse(cpf[i]) * (11 - i);
    }
    resto = 11 - (soma % 11);
    if (resto == 10 || resto == 11) resto = 0;
    if (resto != int.parse(cpf[10])) return false;

    return true;
  }

  bool _validarTelefone(String tel) {
    tel = tel.replaceAll(RegExp(r'[^\d]'), '');
    return tel.length >= 10;
  }

  Future<void> _salvarFuncionario() async {
    String nome = _nomeController.text.trim();
    String sobrenome = _sobrenomeController.text.trim();
    String cpf = _cpfController.text.trim();
    String telefone = _telefoneController.text.trim();
    String email = _emailController.text.trim();
    String senha = _senhaController.text;

    // Validacoes
    if (nome.isEmpty) {
      _mostrarErro('Informe o nome do leiturista.');
      return;
    }
    if (sobrenome.isEmpty) {
      _mostrarErro('Informe o sobrenome (apellido) do leiturista.');
      return;
    }
    if (cpf.isEmpty || !_validarCPF(cpf)) {
      _mostrarErro('CPF invalido. Informe um CPF valido com 11 digitos.');
      return;
    }
    if (telefone.isEmpty || !_validarTelefone(telefone)) {
      _mostrarErro(
          'Telefone invalido. Informe no minimo 10 digitos com DDD.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _mostrarErro('Email invalido.');
      return;
    }
    if (senha.length < 6) {
      _mostrarErro('A senha deve ter no minimo 6 caracteres.');
      return;
    }

    setState(() => _salvando = true);

    try {
      FirebaseApp appFantasma = await Firebase.initializeApp(
        name: 'appFantasma_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      UserCredential credencial = await FirebaseAuth.instanceFor(
        app: appFantasma,
      ).createUserWithEmailAndPassword(
        email: email,
        password: senha,
      );
      await appFantasma.delete();

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credencial.user!.uid)
          .set({
        'nome': '$nome $sobrenome',
        'nome_primeiro': nome,
        'nome_sobrenome': sobrenome,
        'email': email,
        'cpf': cpf.replaceAll(RegExp(r'[^\d]'), ''),
        'telefone': telefone.replaceAll(RegExp(r'[^\d]'), ''),
        'cargo': 'leiturista',
        'id_administradora': widget.idAdministradora,
        'data_cadastro': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leiturista registado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _salvando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no acesso: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _salvando = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.orange),
    );
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
                  'Dados do Leiturista',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Preencha todos os dados obrigatorios. O email e senha serao utilizados para acessar o app.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nomeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _sobrenomeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Sobrenome *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _cpfController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: (value) {
                    final formatted = _formatarCPF(value);
                    if (_cpfController.text != formatted) {
                      _cpfController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'CPF *',
                    hintText: '000.000.000-00',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _telefoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: (value) {
                    final formatted = _formatarTelefone(value);
                    if (_telefoneController.text != formatted) {
                      _telefoneController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(
                          offset: formatted.length,
                        ),
                      );
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Telefone *',
                    hintText: '(00) 00000-0000',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email de Acesso *',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha (minimo 6 caracteres) *',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _salvando
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon:
                              const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            'Criar Acesso',
                            style: TextStyle(
                                fontSize: 18, color: Colors.white),
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
