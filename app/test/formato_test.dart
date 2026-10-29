import 'package:banco_cobol/formato.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pesos agrupa miles y usa coma decimal', () {
    expect(pesos('1500.00'), r'$ 1.500,00');
    expect(pesos('12000.5'), r'$ 12.000,50');
    expect(pesos('0.00'), r'$ 0,00');
    expect(pesos('-250.75'), r'-$ 250,75');
    expect(pesos('1234567.89'), r'$ 1.234.567,89');
  });

  test('normalizarImporte acepta formatos locales', () {
    expect(normalizarImporte('1500'), '1500.00');
    expect(normalizarImporte('1500.5'), '1500.50');
    expect(normalizarImporte('1.500,50'), '1500.50');
    expect(normalizarImporte(r'$ 20,5'), '20.50');
    expect(normalizarImporte('10.555'), isNull);
    expect(normalizarImporte('abc'), isNull);
    expect(normalizarImporte(''), isNull);
  });
}
