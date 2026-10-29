// Clientes: busqueda, ficha con sus cuentas, alta, modificacion, baja y
// apertura de cuentas.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../comun.dart';
import '../formato.dart';
import 'consultas.dart';
import 'operaciones.dart';

enum _Modo { apellido, documento, numero }

class ClientesPantalla extends StatefulWidget {
  const ClientesPantalla({super.key});

  @override
  State<ClientesPantalla> createState() => _ClientesPantallaState();
}

class _ClientesPantallaState extends State<ClientesPantalla> with AccionAsync {
  final _texto = TextEditingController();
  _Modo _modo = _Modo.apellido;
  List<Cliente>? _resultados;

  Future<void> _buscar() async {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    switch (_modo) {
      case _Modo.apellido:
        final r = await correr(() => api.buscarPorApellido(t));
        if (r != null) setState(() => _resultados = r);
      case _Modo.documento:
        final c = await correr(() => api.clientePorDocumento(t));
        if (c != null) _abrir(c.id);
      case _Modo.numero:
        _abrir(int.parse(t));
    }
  }

  Future<void> _abrir(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClienteDetallePantalla(id: id)));
    // Al volver, la lista puede estar desactualizada (baja, nuevas cuentas).
    if (_resultados != null && _modo == _Modo.apellido) {
      final r = await correr(() => api.buscarPorApellido(_texto.text.trim()));
      if (r != null) setState(() => _resultados = r);
    }
  }

  Future<void> _nuevo() async {
    final id = await Navigator.push<int>(context, MaterialPageRoute(builder: (_) => const ClienteNuevoPantalla()));
    if (id != null) _abrir(id);
  }

  @override
  Widget build(BuildContext context) {
    final soloDigitos = _modo != _Modo.apellido;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo cliente'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Contenido(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<_Modo>(
                segments: const [
                  ButtonSegment(value: _Modo.apellido, label: Text('Apellido')),
                  ButtonSegment(value: _Modo.documento, label: Text('Documento')),
                  ButtonSegment(value: _Modo.numero, label: Text('N° cliente')),
                ],
                selected: {_modo},
                onSelectionChanged: (s) => setState(() {
                  _modo = s.first;
                  _texto.clear();
                  _resultados = null;
                  error = null;
                }),
              ),
              espacio,
              TextField(
                controller: _texto,
                decoration: InputDecoration(
                  labelText: switch (_modo) {
                    _Modo.apellido => 'Apellido o comienzo del apellido',
                    _Modo.documento => 'Documento',
                    _Modo.numero => 'Número de cliente',
                  },
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: cargando
                      ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(icon: const Icon(Icons.arrow_forward), onPressed: _buscar),
                ),
                keyboardType: soloDigitos ? TextInputType.number : TextInputType.text,
                inputFormatters: [
                  if (soloDigitos) FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_modo == _Modo.numero ? 6 : (soloDigitos ? 12 : 30)),
                ],
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _buscar(),
              ),
              espacio,
              AvisoError(error),
              if (_resultados != null && _resultados!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No se encontraron clientes.', textAlign: TextAlign.center),
                ),
              if (_resultados != null)
                for (final c in _resultados!)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(c.apellido.isEmpty ? '?' : c.apellido[0])),
                      title: Text(c.nombreCompleto),
                      subtitle: Text('Doc. ${c.documento} · Cliente ${c.numero}'),
                      trailing: c.activo ? null : const ChipEstado('Baja', bueno: false),
                      onTap: () => _abrir(c.id),
                    ),
                  ),
              if (_resultados == null && error == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Busque un cliente para ver sus datos y cuentas, o dé de alta uno nuevo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

// --- Ficha del cliente ---------------------------------------------------------

class ClienteDetallePantalla extends StatefulWidget {
  const ClienteDetallePantalla({super.key, required this.id});

  final int id;

  @override
  State<ClienteDetallePantalla> createState() => _ClienteDetallePantallaState();
}

class _ClienteDetallePantallaState extends State<ClienteDetallePantalla> with AccionAsync {
  Cliente? _cliente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final c = await correr(() => api.cliente(widget.id));
    if (c != null) setState(() => _cliente = c);
  }

  Future<void> _editar() async {
    final cambiado = await showDialog<Cliente>(
      context: context,
      builder: (_) => _EditarClienteDialogo(cliente: _cliente!),
    );
    if (cambiado != null && mounted) {
      setState(() => _cliente = cambiado);
      avisar(context, 'Datos actualizados');
    }
  }

  Future<void> _baja() async {
    final c = _cliente!;
    final ok = await confirmar(context, 'Dar de baja',
        '¿Dar de baja a ${c.nombreCompleto}? Se cerrarán todas sus cuentas. Solo es posible si el saldo total es cero.',
        accion: 'Dar de baja');
    if (!ok) return;
    final mensaje = await correr(() => api.bajaCliente(c.id));
    if (mensaje != null && mounted) {
      avisar(context, mensaje);
      _cargar();
    }
  }

  Future<void> _abrirCuenta() async {
    final cuenta = await Navigator.push<Cuenta>(
        context, MaterialPageRoute(builder: (_) => AbrirCuentaPantalla(cliente: _cliente!)));
    if (cuenta != null) _cargar();
  }

  Future<void> _ir(Widget pantalla, String titulo) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(appBar: AppBar(title: Text(titulo)), body: pantalla)));
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final c = _cliente;
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(c == null ? 'Cliente' : 'Cliente ${c.numero}'),
        actions: [
          if (c != null && c.activo) ...[
            IconButton(tooltip: 'Editar datos', icon: const Icon(Icons.edit_outlined), onPressed: _editar),
            IconButton(tooltip: 'Dar de baja', icon: const Icon(Icons.person_off_outlined), onPressed: _baja),
          ],
        ],
      ),
      floatingActionButton: c != null && c.activo
          ? FloatingActionButton.extended(
              onPressed: _abrirCuenta, icon: const Icon(Icons.add_card), label: const Text('Abrir cuenta'))
          : null,
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Contenido(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AvisoError(error),
                if (c == null && cargando) const Center(child: CircularProgressIndicator()),
                if (c != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(c.nombreCompleto, style: t.textTheme.titleLarge)),
                          ChipEstado(c.activo ? 'Activo' : 'Dado de baja', bueno: c.activo),
                        ]),
                        const SizedBox(height: 12),
                        _Dato(Icons.badge_outlined, 'Documento', c.documento),
                        _Dato(Icons.cake_outlined, 'Nacimiento', fecha(c.fechaNacimiento)),
                        _Dato(Icons.home_outlined, 'Dirección', c.direccion.isEmpty ? '—' : c.direccion),
                        _Dato(Icons.phone_outlined, 'Teléfono', c.telefono.isEmpty ? '—' : c.telefono),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Cuentas', style: t.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (c.cuentas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(c.activo ? 'Sin cuentas. Use "Abrir cuenta" para crear una.' : 'Sin cuentas.'),
                    ),
                  for (final cuenta in c.cuentas)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(cuenta.tipoTexto, style: t.textTheme.titleSmall),
                                Text('N° ${cuenta.numero}', style: t.textTheme.bodySmall),
                              ]),
                            ),
                            chipCuenta(cuenta.estado),
                          ]),
                          const SizedBox(height: 8),
                          Text(pesos(cuenta.saldo), style: t.textTheme.headlineSmall),
                          Wrap(spacing: 4, children: [
                            if (cuenta.estado == 'abierta')
                              TextButton.icon(
                                icon: const Icon(Icons.south_west, size: 18),
                                label: const Text('Depositar'),
                                onPressed: () => _ir(
                                    FormularioOperacion(tipo: TipoOperacion.deposito, cuenta: cuenta.numero),
                                    'Depósito'),
                              ),
                            TextButton.icon(
                              icon: const Icon(Icons.receipt_long_outlined, size: 18),
                              label: const Text('Extracto'),
                              onPressed: () => _ir(ExtractoVista(cuenta: cuenta.numero), 'Extracto'),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                ],
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.etiqueta, this.valor);

  final IconData icono;
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icono, size: 20, color: t.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        SizedBox(width: 96, child: Text(etiqueta, style: TextStyle(color: t.colorScheme.onSurfaceVariant))),
        Expanded(child: Text(valor)),
      ]),
    );
  }
}

class _EditarClienteDialogo extends StatefulWidget {
  const _EditarClienteDialogo({required this.cliente});

  final Cliente cliente;

  @override
  State<_EditarClienteDialogo> createState() => _EditarClienteDialogoState();
}

class _EditarClienteDialogoState extends State<_EditarClienteDialogo> with AccionAsync {
  late final _direccion = TextEditingController(text: widget.cliente.direccion);
  late final _telefono = TextEditingController(text: widget.cliente.telefono);

  Future<void> _guardar() async {
    final c = await correr(() => api.modificarCliente(widget.cliente.id,
        direccion: _direccion.text.trim(), telefono: _telefono.text.trim()));
    if (c != null && mounted) Navigator.pop(context, c);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Editar datos'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AvisoError(error),
            TextField(
              controller: _direccion,
              decoration: const InputDecoration(labelText: 'Dirección'),
              inputFormatters: [LengthLimitingTextInputFormatter(50)],
            ),
            espacio,
            TextField(
              controller: _telefono,
              decoration: const InputDecoration(labelText: 'Teléfono'),
              keyboardType: TextInputType.phone,
              inputFormatters: [LengthLimitingTextInputFormatter(15)],
            ),
            const SizedBox(height: 8),
            Text('Un campo vacío conserva el valor actual.', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          BotonCarga(texto: 'Guardar', cargando: cargando, onPressed: _guardar),
        ],
      );
}

// --- Alta de cliente -----------------------------------------------------------

class ClienteNuevoPantalla extends StatefulWidget {
  const ClienteNuevoPantalla({super.key});

  @override
  State<ClienteNuevoPantalla> createState() => _ClienteNuevoPantallaState();
}

class _ClienteNuevoPantallaState extends State<ClienteNuevoPantalla> with AccionAsync {
  final _form = GlobalKey<FormState>();
  final _documento = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  DateTime? _nacimiento;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final c = await correr(() => api.altaCliente(
          documento: _documento.text,
          nombre: _nombre.text.trim(),
          apellido: _apellido.text.trim(),
          fechaNacimiento: _nacimiento!,
          direccion: _direccion.text.trim(),
          telefono: _telefono.text.trim(),
        ));
    if (c != null && mounted) {
      avisar(context, 'Cliente ${c.numero} dado de alta');
      Navigator.pop(context, c.id);
    }
  }

  String? _obligatorio(String? v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo cliente')),
      body: ListView(children: [
        Contenido(
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AvisoError(error),
              TextFormField(
                controller: _documento,
                decoration: const InputDecoration(labelText: 'Documento', prefixIcon: Icon(Icons.badge_outlined)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                validator: (v) => (v == null || v.length < 7) ? 'Entre 7 y 12 dígitos' : null,
              ),
              espacio,
              TextFormField(
                controller: _nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                validator: _obligatorio,
              ),
              espacio,
              TextFormField(
                controller: _apellido,
                decoration: const InputDecoration(labelText: 'Apellido'),
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(30)],
                validator: _obligatorio,
              ),
              espacio,
              CampoFecha(
                etiqueta: 'Fecha de nacimiento',
                valor: _nacimiento,
                primera: DateTime(1900),
                ultima: DateTime(hoy.year - 18, hoy.month, hoy.day),
                onCambio: (d) => setState(() => _nacimiento = d),
              ),
              espacio,
              TextFormField(
                controller: _direccion,
                decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
                inputFormatters: [LengthLimitingTextInputFormatter(50)],
              ),
              espacio,
              TextFormField(
                controller: _telefono,
                decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
                keyboardType: TextInputType.phone,
                inputFormatters: [LengthLimitingTextInputFormatter(15)],
              ),
              const SizedBox(height: 24),
              BotonCarga(texto: 'Dar de alta', icono: Icons.person_add_alt_1, cargando: cargando, onPressed: _guardar),
            ]),
          ),
        ),
      ]),
    );
  }
}

// --- Apertura de cuenta --------------------------------------------------------

class AbrirCuentaPantalla extends StatefulWidget {
  const AbrirCuentaPantalla({super.key, required this.cliente});

  final Cliente cliente;

  @override
  State<AbrirCuentaPantalla> createState() => _AbrirCuentaPantallaState();
}

class _AbrirCuentaPantallaState extends State<AbrirCuentaPantalla> with AccionAsync {
  final _form = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  final _deposito = TextEditingController();
  String _tipo = 'ahorro';

  Future<void> _abrir() async {
    if (!_form.currentState!.validate()) return;
    final deposito = _deposito.text.trim().isEmpty ? '0.00' : normalizarImporte(_deposito.text)!;
    final cuenta = await correr(() => api.abrirCuenta(
        clienteId: widget.cliente.id, tipo: _tipo, pin: _pin.text, depositoInicial: deposito));
    if (cuenta == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, size: 40),
        title: const Text('Cuenta abierta'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(cuenta.tipoTexto),
          const SizedBox(height: 8),
          SelectableText(cuenta.numero, style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Saldo inicial: ${pesos(cuenta.saldo)}'),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Aceptar'))],
      ),
    );
    if (mounted) Navigator.pop(context, cuenta);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Abrir cuenta')),
        body: ListView(children: [
          Contenido(
            child: Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(widget.cliente.nombreCompleto),
                  subtitle: Text('Cliente ${widget.cliente.numero} · Doc. ${widget.cliente.documento}'),
                ),
                espacio,
                AvisoError(error),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ahorro', label: Text('Caja de ahorro'), icon: Icon(Icons.savings_outlined)),
                    ButtonSegment(value: 'corriente', label: Text('Cuenta corriente'), icon: Icon(Icons.account_balance_wallet_outlined)),
                  ],
                  selected: {_tipo},
                  onSelectionChanged: (s) => setState(() => _tipo = s.first),
                ),
                espacio,
                CampoPin(controller: _pin, etiqueta: 'PIN (4 dígitos)'),
                espacio,
                CampoPin(
                  controller: _pin2,
                  etiqueta: 'Repetir PIN',
                  validar: (v) => v == _pin.text ? null : 'Los PIN no coinciden',
                ),
                espacio,
                CampoImporte(controller: _deposito, etiqueta: 'Depósito inicial (opcional)', permiteCero: true),
                const SizedBox(height: 24),
                BotonCarga(texto: 'Abrir cuenta', icono: Icons.add_card, cargando: cargando, onPressed: _abrir),
              ]),
            ),
          ),
        ]),
      );
}
