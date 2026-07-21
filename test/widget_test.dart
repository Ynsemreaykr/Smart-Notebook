import 'package:flutter_test/flutter_test.dart';
import 'package:smart_notebook/app.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartNotebookApp());
    expect(find.text('Kitaplık'), findsAny);
  });
}
