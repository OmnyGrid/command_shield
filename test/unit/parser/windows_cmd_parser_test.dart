import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  const parser = WindowsCmdParser();

  CommandNode ast(String raw) => parser.parse(raw).ast!;

  group('WindowsCmdParser', () {
    test('reports windowsCmd syntax', () {
      expect(parser.syntax, CommandSyntax.windowsCmd);
    });

    test('simple command', () {
      final inv = ast('dir') as CommandInvocation;
      expect(inv.executable, 'dir');
    });

    test('cmd /c dir', () {
      final inv = ast('cmd /c dir') as CommandInvocation;
      expect(inv.executable, 'cmd');
      expect(inv.arguments, ['/c', 'dir']);
    });

    test('%TEMP% environment reference', () {
      final inv = ast('echo %TEMP%') as CommandInvocation;
      expect(inv.environmentReferences.map((e) => e.variable), ['TEMP']);
    });

    test('& sequential separator', () {
      final node = ast('dir & echo done') as CommandChain;
      expect(node.operator, ChainOperator.sequential);
    });

    test('&& conditional', () {
      final node = ast('build && test') as CommandChain;
      expect(node.operator, ChainOperator.and);
    });

    test('|| conditional', () {
      final node = ast('build || echo fail') as CommandChain;
      expect(node.operator, ChainOperator.or);
    });

    test('pipeline', () {
      final node = ast('dir | find "x"') as Pipeline;
      expect(node.commands, hasLength(2));
    });

    test('redirection', () {
      final inv = ast('echo hi > out.txt') as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.output);
    });

    test('double quotes group text', () {
      final inv = ast('echo "a b"') as CommandInvocation;
      expect(inv.arguments, ['a b']);
    });

    test('empty input yields no AST', () {
      expect(parser.parse('').ast, isNull);
    });

    test('unterminated quote warns', () {
      final result = parser.parse('echo "oops');
      expect(
        result.diagnostics.any((d) => d.severity == DiagnosticSeverity.warning),
        isTrue,
      );
    });

    test('lone percent is literal', () {
      final inv = ast('echo 50%') as CommandInvocation;
      expect(inv.arguments, ['50%']);
      expect(inv.environmentReferences, isEmpty);
    });
  });
}
