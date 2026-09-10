import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('UUID test', () {
    for (int i = 0; i < 5; i++) {
      print(const Uuid().v4());
    }
  });
}
