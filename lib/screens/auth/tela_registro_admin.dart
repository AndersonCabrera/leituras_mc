import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/tela_admin_dashboard.dart';
import '../../core/theme.dart';
import '../../services/cep_service.dart';

class TelaRegistroAdmin extends StatefulWidget {
  const TelaRegistroAdmin({super.key});

  @override
  State<TelaRegistroAdmin> createState() => _TelaRegistroAdminState();
}

class _TelaRegistroAdminState extends State<TelaRegistroAdmin> {
  final _nomeEmpresaController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _nomeGestorController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cepController = TextEditingController();
  final _logradouroController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;
  bool _buscandoCep = false;

  @override
  void dispose() {
    _nomeEmpresaController.dispose();
    _cnpjController.dispose();
    _nomeGestorController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  String _formatarCNPJ(String value) {
    value = value.replaceAll(RegExp(r'[^\d]'), '');
    if (value.length > 14) value = value.substring(0, 14);
    if (value.length > 12) {
      return '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5, 8)}/${value.substring(8, 12)}-${value.substring(12)}';
    } else if (value.length > 8) {
      return '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5, 8)}/${value.substring(8)}';
    } else if (value.length > 5) {
      return '${value.substring(0, 2)}.${value.substring(2, 5)}.${value.substring(5)}';
    } else if (value.length > 2) {
      return '${value.substring(0, 2)}.${value.substring(2)}';
    }
    return value;
  }

  bool _validarCNPJ(String cnpj) {
    cnpj = cnpj.replaceAll(RegExp(r'[^\d]'), '');
    if (cnpj.length != 14) return false;
    if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;

    List<int> pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    List<int> pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

    int soma = 0;
    for (int i = 0; i < 12; i++) {
      soma += int.parse(cnpj[i]) * pesos1[i];
    }
    int resto = soma % 11;
    int digito1 = resto < 2 ? 0 : 11 - resto;
    if (int.parse(cnpj[12]) != digito1) return false;

    soma = 0;
    for (int i = 0; i < 13; i++) {
      soma += int.parse(cnpj[i]) * pesos2[i];
    }
    resto = soma % 11;
    int digito2 = resto < 2 ? 0 : 11 - resto;
    return int.parse(cnpj[13]) == digito2;
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

  String _formatarCEP(String value) {
    value = value.replaceAll(RegExp(r'[^\d]'), '');
    if (value.length > 8) value = value.substring(0, 8);
    if (value.length > 5) {
      return '${value.substring(0, 5)}-${value.substring(5)}';
    }
    return value;
  }

  Future<void> _buscarCEP() async {
    final cep = _cepController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cep.length != 8) return;

    setState(() => _buscandoCep = true);

    final resultado = await CepService.buscar(cep);

    if (mounted) {
      setState(() => _buscandoCep = false);
      if (!resultado.erro) {
        _logradouroController.text = resultado.logradouro;
        _bairroController.text = resultado.bairro;
        _cidadeController.text = resultado.cidade;
        _ufController.text = resultado.uf;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CEP não encontrado. Preencha o endereço manualmente.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _cadastrar() async {
    if (_nomeEmpresaController.text.trim().isEmpty ||
        _cnpjController.text.trim().isEmpty ||
        _nomeGestorController.text.trim().isEmpty ||
        _telefoneController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _cepController.text.trim().isEmpty ||
        _logradouroController.text.trim().isEmpty ||
        _numeroController.text.trim().isEmpty ||
        _bairroController.text.trim().isEmpty ||
        _cidadeController.text.trim().isEmpty ||
        _ufController.text.trim().isEmpty ||
        _senhaController.text.isEmpty) {
      _mostrarErro('Preencha todos os campos obrigatórios.');
      return;
    }

    String cnpjLimpo = _cnpjController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (!_validarCNPJ(cnpjLimpo)) {
      _mostrarErro('CNPJ inválido.');
      return;
    }

    String telefoneLimpo = _telefoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (telefoneLimpo.length < 10) {
      _mostrarErro('Telefone inválido (mínimo 10 dígitos).');
      return;
    }

    String cepLimpo = _cepController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cepLimpo.length != 8) {
      _mostrarErro('CEP inválido (8 dígitos).');
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

    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      _mostrarErro('Email inválido. Informe um email válido (ex: nome@dominio.com).');
      return;
    }

    setState(() => _carregando = true);

    try {
      var existente = await FirebaseFirestore.instance
          .collection('administradoras')
          .where('cnpj', isEqualTo: cnpjLimpo)
          .limit(1)
          .get();
      if (existente.docs.isNotEmpty) {
        _mostrarErro('Já existe uma empresa cadastrada com este CNPJ.');
        setState(() => _carregando = false);
        return;
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
            'cnpj': cnpjLimpo,
            'nome_gestor': _nomeGestorController.text.trim(),
            'email': _emailController.text.trim(),
            'telefone': _telefoneController.text.trim(),
            'cep': _cepController.text.trim(),
            'logradouro': _logradouroController.text.trim(),
            'numero': _numeroController.text.trim(),
            'bairro': _bairroController.text.trim(),
            'cidade': _cidadeController.text.trim(),
            'uf': _ufController.text.trim().toUpperCase(),
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

                // === DADOS DA EMPRESA ===
                _secaoTitulo('Dados da Empresa'),
                const SizedBox(height: 10),
                TextField(
                  controller: _nomeEmpresaController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDec(
                    label: 'Nome da Empresa *',
                    icon: Icons.business,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _cnpjController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(14),
                  ],
                  onChanged: (v) {
                    final formatado = _formatarCNPJ(v);
                    if (formatado != v) {
                      _cnpjController.value = TextEditingValue(
                        text: formatado,
                        selection: TextSelection.collapsed(offset: formatado.length),
                      );
                    }
                  },
                  decoration: _inputDec(
                    label: 'CNPJ *',
                    icon: Icons.credit_card,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _telefoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  onChanged: (v) {
                    final formatado = _formatarTelefone(v);
                    if (formatado != v) {
                      _telefoneController.value = TextEditingValue(
                        text: formatado,
                        selection: TextSelection.collapsed(offset: formatado.length),
                      );
                    }
                  },
                  decoration: _inputDec(
                    label: 'Telefone *',
                    icon: Icons.phone,
                  ),
                ),
                const SizedBox(height: 20),

                // === DADOS DO RESPONSÁVEL ===
                _secaoTitulo('Dados do Responsável'),
                const SizedBox(height: 10),
                TextField(
                  controller: _nomeGestorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDec(
                    label: 'Nome Completo *',
                    icon: Icons.person,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDec(
                    label: 'E-mail *',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 20),

                // === ENDEREÇO ===
                _secaoTitulo('Endereço'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _cepController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(8),
                        ],
                        onChanged: (v) {
                          final formatado = _formatarCEP(v);
                          if (formatado != v) {
                            _cepController.value = TextEditingValue(
                              text: formatado,
                              selection: TextSelection.collapsed(offset: formatado.length),
                            );
                          }
                          if (v.replaceAll(RegExp(r'[^\d]'), '').length == 8) {
                            _buscarCEP();
                          }
                        },
                        decoration: _inputDec(
                          label: 'CEP *',
                          icon: Icons.location_on,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_buscandoCep)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _logradouroController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDec(
                    label: 'Logradouro *',
                    icon: Icons.add_road,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _numeroController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDec(
                          label: 'Número *',
                          icon: Icons.tag,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _bairroController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDec(
                          label: 'Bairro *',
                          icon: Icons.location_city,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _cidadeController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _inputDec(
                          label: 'Cidade *',
                          icon: Icons.location_city,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _ufController,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 2,
                        decoration: _inputDec(
                          label: 'UF *',
                          icon: Icons.map,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // === SENHA ===
                _secaoTitulo('Senha'),
                const SizedBox(height: 10),
                TextField(
                  controller: _senhaController,
                  obscureText: _ocultarSenha,
                  decoration: _inputDec(
                    label: 'Senha *',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _ocultarSenha ? Icons.visibility_off : Icons.visibility,
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
                    label: 'Confirmar Senha *',
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

  Widget _secaoTitulo(String titulo) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
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
