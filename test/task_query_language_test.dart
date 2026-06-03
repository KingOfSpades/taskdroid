import 'package:flutter_test/flutter_test.dart';
import 'package:taskdroid/services/task_query_language.dart';

void main() {
  group('Task query language', () {
    test('explicit non-pending status clauses broaden display scope', () {
      final query = parseTaskQuery('status:completed');

      expect(query.usesExplicitStatusScope, isTrue);
    });

    test('negative-only status clauses stay in queue scope', () {
      final query = parseTaskQuery('-COMPLETED -DELETED');

      expect(query.usesExplicitStatusScope, isFalse);
    });

    test('pending status clauses stay in queue scope', () {
      final query = parseTaskQuery('status:pending');

      expect(query.usesExplicitStatusScope, isFalse);
    });

    test('surfaces parse issues for malformed query', () {
      final query = parseTaskQuery('(project:work or');

      expect(query.hasErrors, isTrue);
      expect(query.issues, isNotEmpty);
    });

    test('taskwarrior-style query examples parse without errors', () {
      const examples = [
        '(+ACTIVE or +DUE or +OVERDUE) +READY',
        '(+READY +PROJECT) -DUE -DUETODAY -OVERDUE -ACTIVE',
        '(-COMPLETED -DELETED wait:someday)',
        '-COMPLETED -DELETED -TEMPLATE',
        '(+COMPLETED)',
        '-COMPLETED -DELETED -PROJECT',
      ];

      for (final example in examples) {
        final parsed = parseTaskQuery(example);
        expect(parsed.hasErrors, isFalse, reason: example);
        expect(parsed.termCount, greaterThan(0), reason: example);
      }
    });
  });
}
