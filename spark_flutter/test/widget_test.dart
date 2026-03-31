import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spark_flutter/shared/app/spark_app.dart';

void main() {
  testWidgets('shows Spark discovery shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SparkApp()));

    expect(find.text('Nearby plans,\nmade easy.'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });
}
