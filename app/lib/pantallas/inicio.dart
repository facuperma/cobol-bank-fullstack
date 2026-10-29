// Estructura principal: barra lateral en pantallas anchas, barra inferior
// en el celular. La seccion de supervisor solo aparece para ese rol.

import 'package:flutter/material.dart';

import '../comun.dart';
import 'clientes.dart';
import 'consultas.dart';
import 'operaciones.dart';
import 'supervisor.dart';

class _Seccion {
  const _Seccion(this.titulo, this.icono, this.iconoActivo, this.pantalla);

  final String titulo;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;
}

class InicioPantalla extends StatefulWidget {
  const InicioPantalla({super.key});

  @override
  State<InicioPantalla> createState() => _InicioPantallaState();
}

class _InicioPantallaState extends State<InicioPantalla> {
  int _actual = 0;

  @override
  Widget build(BuildContext context) {
    final api = ApiScope.of(context);
    final usuario = api.usuario!;
    final secciones = [
      const _Seccion('Clientes', Icons.people_outline, Icons.people, ClientesPantalla()),
      const _Seccion('Operaciones', Icons.swap_horiz, Icons.swap_horiz, OperacionesPantalla()),
      const _Seccion('Consultas', Icons.receipt_long_outlined, Icons.receipt_long, ConsultasPantalla()),
      if (usuario.supervisor)
        const _Seccion('Supervisor', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings,
            SupervisorPantalla()),
    ];
    final ancha = MediaQuery.sizeOf(context).width >= 840;
    final rol = usuario.supervisor ? 'Supervisor' : 'Cajero';
    final seccion = secciones[_actual];

    final cuerpo = IndexedStack(index: _actual, children: [for (final s in secciones) s.pantalla]);

    return Scaffold(
      appBar: AppBar(
        title: Text(seccion.titulo),
        actions: [
          if (ancha)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text('${usuario.nombre} · $rol', style: Theme.of(context).textTheme.labelLarge),
              ),
            ),
          PopupMenuButton<void>(
            tooltip: 'Sesión',
            icon: const Icon(Icons.account_circle_outlined),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(usuario.nombre),
                  subtitle: Text('${usuario.usuario} · $rol'),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                ),
                onTap: () async {
                  if (await confirmar(context, 'Cerrar sesión', '¿Desea salir del sistema?', accion: 'Salir')) {
                    await api.logout();
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: ancha
          ? Row(children: [
              NavigationRail(
                selectedIndex: _actual,
                onDestinationSelected: (i) => setState(() => _actual = i),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Icon(Icons.account_balance, color: Theme.of(context).colorScheme.primary),
                ),
                destinations: [
                  for (final s in secciones)
                    NavigationRailDestination(
                        icon: Icon(s.icono), selectedIcon: Icon(s.iconoActivo), label: Text(s.titulo)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: cuerpo),
            ])
          : cuerpo,
      bottomNavigationBar: ancha
          ? null
          : NavigationBar(
              selectedIndex: _actual,
              onDestinationSelected: (i) => setState(() => _actual = i),
              destinations: [
                for (final s in secciones)
                  NavigationDestination(icon: Icon(s.icono), selectedIcon: Icon(s.iconoActivo), label: s.titulo),
              ],
            ),
    );
  }
}
