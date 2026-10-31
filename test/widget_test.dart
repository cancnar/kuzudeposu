import 'package:flutter_test/flutter_test.dart';
import 'package:kuzu_deposu/theme.dart';

void main() {
  test('tema oluşturulur', () {
    expect(kuzuTema().useMaterial3, isTrue);
  });
}
