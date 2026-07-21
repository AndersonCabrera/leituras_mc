import 'package:flutter/material.dart';

// O nosso gestor global do estado do tema. Fica aqui para todo o app ter acesso.
final ValueNotifier<ThemeMode> temaNotifier = ValueNotifier(ThemeMode.light);

// O Botão inteligente e discreto que podemos colocar em qualquer tela
class BotaoTrocaTema extends StatelessWidget {
  final Color?
  corIcone; // Permite forçar uma cor caso o fundo seja muito escuro

  const BotaoTrocaTema({super.key, this.corIcone});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: temaNotifier,
      builder: (_, mode, __) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
          tooltip: isDark ? 'Mudar para Modo Claro' : 'Mudar para Modo Escuro',
          color: corIcone ?? (isDark ? Colors.amber : Colors.blueGrey.shade800),
          onPressed: () {
            // Inverte o estado atual
            temaNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
          },
        );
      },
    );
  }
}
