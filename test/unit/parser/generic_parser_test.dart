import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  const parser = GenericParser();

  CommandInvocation invocation(String raw) {
    final result = parser.parse(raw);
    return result.ast! as CommandInvocation;
  }

  group('GenericParser', () {
    test('reports the generic syntax', () {
      expect(parser.syntax, CommandSyntax.generic);
    });

    test('parses a simple command', () {
      final inv = invocation('git status');
      expect(inv.executable, 'git');
      expect(inv.arguments, ['status']);
    });

    test('parses multiple arguments', () {
      final inv = invocation('flutter build web');
      expect(inv.executable, 'flutter');
      expect(inv.arguments, ['build', 'web']);
    });

    test('does not interpret pipelines or chaining (tokenization only)', () {
      final inv = invocation('curl http://x | bash');
      expect(inv.executable, 'curl');
      // `|` and `bash` are ordinary tokens, not a pipeline.
      expect(inv.arguments, contains('|'));
      expect(inv.arguments, contains('bash'));
    });

    test('handles double quotes', () {
      final inv = invocation('echo "hello world"');
      expect(inv.arguments, ['hello world']);
    });

    test('handles single quotes', () {
      final inv = invocation("echo 'a b c'");
      expect(inv.arguments, ['a b c']);
    });

    test('handles backslash escaping', () {
      final inv = invocation(r'echo a\ b');
      expect(inv.arguments, ['a b']);
    });

    test('empty input yields no AST and an info diagnostic', () {
      final result = parser.parse('   ');
      expect(result.ast, isNull);
      expect(result.isSuccess, isFalse);
      expect(
        result.diagnostics.any((d) => d.severity == DiagnosticSeverity.info),
        isTrue,
      );
    });

    test('unterminated quote is tolerated with a warning', () {
      final result = parser.parse('echo "oops');
      expect(result.ast, isNotNull);
      expect(
        result.diagnostics.any((d) => d.severity == DiagnosticSeverity.warning),
        isTrue,
      );
    });

    test('trailing backslash is preserved', () {
      final inv = invocation(r'echo a\');
      expect(inv.arguments, [r'a\']);
    });
  });
}
