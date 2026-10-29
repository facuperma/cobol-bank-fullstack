// Funciones de supervisor: desbloqueo de cuentas y procesos batch.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../comun.dart';
import '../formato.dart';

class _Proceso {
  const _Proceso(this.clave, this.titulo, this.descripcion, this.icono, {this.modifica = false});

  final String clave;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool modifica;
}

const _procesos = [
  _Proceso('interes', 'Intereses', 'Acredita los intereses del mes en las cajas de ahorro. Se paga una vez por período.',
      Icons.percent, modifica: true),
  _Proceso('cierre', 'Cierre mensual', 'Resumen de operaciones, clientes y cartera del período.', Icons.summarize_outlined),
  _Proceso('reconcil', 'Reconciliación', 'Compara cada saldo con la suma de sus movimientos.', Icons.fact_check_outlined),
  _Proceso('ranking', 'Ranking de clientes', 'Clientes activos ordenados por saldo total.', Icons.leaderboard_outlined),
  _Proceso('exporta', 'Exportación', 'Archivo plano de ancho fijo con los movimientos del período.', Icons.file_download_outlined),
];

class SupervisorPantalla extends StatefulWidget {
  const SupervisorPantalla({super.key});

  @override
  State<SupervisorPantalla> createState() => _SupervisorPantallaState();
}

class _SupervisorPantallaState extends State<SupervisorPantalla> with AccionAsync {
  final _cuenta = TextEditingController();
  final _periodo = TextEditingController(text: periodoActual());
  final _tasa = TextEditingController(text: '6.00');
  String? _corriendo;

  Future<void> _desbloquear() async {
    if (_cuenta.text.isEmpty) return;
    final mensaje = await correr(() => api.desbloquear(_cuenta.text));
    if (mensaje != null && mounted) {
      avisar(context, mensaje);
      _cuenta.clear();
    }
  }

  Future<void> _correr(_Proceso p) async {
    final periodo = _periodo.text.trim();
    if (!RegExp(r'^\d{4}(0[1-9]|1[0-2])$').hasMatch(periodo)) {
      setState(() => error = 'Período inválido (use AAAAMM)');
      return;
    }
    if (p.modifica &&
        !await confirmar(context, p.titulo, 'Se acreditarán intereses del período $periodo con tasa anual ${_tasa.text}%.',
            accion: 'Ejecutar')) {
      return;
    }
    setState(() => _corriendo = p.clave);
    final r = await correr(() => api.proceso(p.clave, periodo: periodo, tasa: p.modifica ? _tasa.text.trim() : null));
    if (!mounted) return;
    setState(() => _corriendo = null);
    if (r != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => _ResultadoPantalla(p.titulo, r)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(children: [
      Contenido(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AvisoError(error),
          Text('Desbloquear cuenta', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Las cuentas se bloquean después de 3 PIN incorrectos.', style: t.textTheme.bodySmall),
          espacio,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: CampoCuenta(controller: _cuenta)),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: cargando ? null : _desbloquear,
              icon: const Icon(Icons.lock_open),
              label: const Text('Desbloquear'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            ),
          ]),
          const Divider(height: 48),
          Text('Procesos batch', style: t.textTheme.titleMedium),
          espacio,
          Row(children: [
            Expanded(
              child: TextField(
                controller: _periodo,
                decoration: const InputDecoration(labelText: 'Período (AAAAMM)'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _tasa,
                decoration: const InputDecoration(labelText: 'Tasa anual (%)', helperText: 'Solo intereses'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          espacio,
          for (final p in _procesos)
            Card(
              child: ListTile(
                leading: Icon(p.icono),
                title: Text(p.titulo),
                subtitle: Text(p.descripcion),
                trailing: _corriendo == p.clave
                    ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                onTap: cargando ? null : () => _correr(p),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _ResultadoPantalla extends StatelessWidget {
  const _ResultadoPantalla(this.titulo, this.r);

  final String titulo;
  final ResultadoProceso r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ok = r.rc == 0;
    final mono = t.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.4);
    Widget bloque(String texto) => Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: SelectableText(texto, style: mono),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text('$titulo · ${r.periodo}')),
      body: ListView(children: [
        Contenido(
          ancho: 960,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(ok ? Icons.check_circle : Icons.warning_amber,
                  color: ok ? Colors.green.shade700 : t.colorScheme.error, size: 32),
              title: Text(ok ? 'Proceso finalizado' : 'Finalizó con observaciones'),
              subtitle: Text('Código de retorno ${r.rc}'),
            ),
            espacio,
            Text('Salida', style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            bloque(r.salida),
            if (r.reporte != null) ...[
              espacio,
              Text('Informe', style: t.textTheme.titleSmall),
              const SizedBox(height: 8),
              bloque(r.reporte!),
            ],
          ]),
        ),
      ]),
    );
  }
}
