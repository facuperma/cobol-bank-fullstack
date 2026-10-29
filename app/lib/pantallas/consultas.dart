// Consulta de saldo (con PIN) y extracto de movimientos por periodo.

import 'package:flutter/material.dart';

import '../api.dart';
import '../comun.dart';
import '../formato.dart';

class ConsultasPantalla extends StatelessWidget {
  const ConsultasPantalla({super.key});

  @override
  Widget build(BuildContext context) => const DefaultTabController(
        length: 2,
        child: Column(children: [
          TabBar(tabs: [
            Tab(text: 'Saldo', icon: Icon(Icons.account_balance_wallet_outlined)),
            Tab(text: 'Extracto', icon: Icon(Icons.receipt_long_outlined)),
          ]),
          Expanded(child: TabBarView(children: [_SaldoVista(), ExtractoVista()])),
        ]),
      );
}

class _SaldoVista extends StatefulWidget {
  const _SaldoVista();

  @override
  State<_SaldoVista> createState() => _SaldoVistaState();
}

class _SaldoVistaState extends State<_SaldoVista> with AccionAsync, AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  final _cuenta = TextEditingController();
  final _pin = TextEditingController();
  Saldo? _saldo;

  @override
  bool get wantKeepAlive => true;

  Future<void> _consultar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saldo = null);
    final s = await correr(() => api.saldo(_cuenta.text, _pin.text));
    _pin.clear();
    if (s != null) setState(() => _saldo = s);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context);
    return ListView(children: [
      Contenido(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AvisoError(error),
            CampoCuenta(controller: _cuenta),
            espacio,
            CampoPin(controller: _pin),
            const SizedBox(height: 24),
            BotonCarga(texto: 'Consultar', icono: Icons.search, cargando: cargando, onPressed: _consultar),
            if (_saldo != null) ...[
              const SizedBox(height: 24),
              Card(
                color: t.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_saldo!.titular, style: t.textTheme.titleMedium),
                    Text(
                        '${_saldo!.tipo == 'ahorro' ? 'Caja de ahorro' : 'Cuenta corriente'} · N° ${_saldo!.numero}',
                        style: t.textTheme.bodySmall),
                    const SizedBox(height: 16),
                    Text('Saldo disponible', style: t.textTheme.labelMedium),
                    Text(pesos(_saldo!.saldo), style: t.textTheme.displaySmall),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class ExtractoVista extends StatefulWidget {
  const ExtractoVista({super.key, this.cuenta});

  final String? cuenta;

  @override
  State<ExtractoVista> createState() => _ExtractoVistaState();
}

class _ExtractoVistaState extends State<ExtractoVista> with AccionAsync, AutomaticKeepAliveClientMixin {
  final _form = GlobalKey<FormState>();
  late final _cuenta = TextEditingController(text: widget.cuenta);
  DateTime _desde = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _hasta = DateTime.now();
  Extracto? _extracto;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.cuenta != null) WidgetsBinding.instance.addPostFrameCallback((_) => _consultar());
  }

  Future<void> _consultar() async {
    if (!_form.currentState!.validate()) return;
    if (_desde.isAfter(_hasta)) {
      setState(() => error = 'La fecha "desde" es posterior a "hasta"');
      return;
    }
    final e = await correr(() => api.extracto(_cuenta.text, _desde, _hasta));
    if (e != null) setState(() => _extracto = e);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context);
    final e = _extracto;
    return ListView(children: [
      Contenido(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AvisoError(error),
              CampoCuenta(controller: _cuenta),
              espacio,
              Row(children: [
                Expanded(
                    child: CampoFecha(
                        etiqueta: 'Desde', valor: _desde, onCambio: (d) => setState(() => _desde = d))),
                const SizedBox(width: 12),
                Expanded(
                    child: CampoFecha(
                        etiqueta: 'Hasta', valor: _hasta, onCambio: (d) => setState(() => _hasta = d))),
              ]),
              const SizedBox(height: 24),
              BotonCarga(
                  texto: 'Ver extracto', icono: Icons.receipt_long, cargando: cargando, onPressed: _consultar),
            ]),
          ),
          if (e != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.titular, style: t.textTheme.titleMedium),
                  Text('Cuenta ${e.cuenta} · ${fecha(_desde)} al ${fecha(_hasta)}', style: t.textTheme.bodySmall),
                  const Divider(height: 24),
                  _Total('Saldo inicial', e.saldoInicial),
                  _Total('Créditos', e.creditos, signo: '+'),
                  _Total('Débitos', e.debitos, signo: '−'),
                  const Divider(height: 24),
                  _Total('Saldo final', e.saldoFinal, destacado: true),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text('${e.movimientos.length} movimiento${e.movimientos.length == 1 ? '' : 's'}',
                style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (e.movimientos.isEmpty) const Text('Sin movimientos en el período.'),
            for (final m in e.movimientos) _FilaMovimiento(m),
          ],
        ]),
      ),
    ]);
  }
}

class _Total extends StatelessWidget {
  const _Total(this.etiqueta, this.importe, {this.signo = '', this.destacado = false});

  final String etiqueta;
  final String importe;
  final String signo;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final estilo = destacado ? Theme.of(context).textTheme.titleMedium : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(etiqueta, style: estilo)),
        Text('$signo ${pesos(importe)}'.trim(), style: estilo),
      ]),
    );
  }
}

class _FilaMovimiento extends StatelessWidget {
  const _FilaMovimiento(this.m);

  final Movimiento m;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = m.esCredito ? Colors.green.shade700 : c.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(m.esCredito ? Icons.south_west : Icons.north_east, size: 20),
        ),
        title: Text(m.tipoTexto),
        subtitle: Text('${fecha(m.fecha)} ${m.hora.substring(0, 5)} · ${m.descripcion}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${m.esCredito ? '+' : '−'} ${pesos(m.importe)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            Text(pesos(m.saldo), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
