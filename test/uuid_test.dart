import 'dart:math';

import 'package:elevenward/src/util/uuid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates stable RFC 4122 version 4 shape', () {
    final uuid = generateUuidV4(Random(42));
    expect(
      uuid,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(uuidSeed(uuid), greaterThan(0));
  });
}
