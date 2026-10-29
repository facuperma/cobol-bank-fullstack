// Formato de importes y fechas para mostrar, y normalizacion de lo que
// escribe el usuario. Todo sobre texto: el dinero nunca pasa por double.

/// "1500.5" / "-20.00" -> "$ 1.500,50" / "-$ 20,00".
String pesos(String importe) {
  final negativo = importe.startsWith('-');
  final partes = (negativo ? importe.substring(1) : importe).split('.');
  final entero = partes[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final decimales = (partes.length > 1 ? partes[1] : '').padRight(2, '0').substring(0, 2);
  final miles = StringBuffer();
  for (var i = 0; i < entero.length; i++) {
    if (i > 0 && (entero.length - i) % 3 == 0) miles.write('.');
    miles.write(entero[i]);
  }
  return '${negativo ? '-' : ''}\$ $miles,$decimales';
}

/// Acepta "1500", "1500.5", "1.500,50" o "1500,5" y devuelve "1500.50";
/// null si no es un importe valido (hasta 2 decimales).
String? normalizarImporte(String texto) {
  var t = texto.trim().replaceAll(' ', '').replaceAll(r'$', '');
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  final m = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final entero = int.parse(m[1]!).toString();
  return '$entero.${(m[2] ?? '').padRight(2, '0')}';
}

bool esCero(String importe) => RegExp(r'^0+(\.0*)?$').hasMatch(importe);

String fecha(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String periodoActual() {
  final hoy = DateTime.now();
  return '${hoy.year}${hoy.month.toString().padLeft(2, '0')}';
}
