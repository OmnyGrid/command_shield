import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  group('ParserFactory', () {
    test('resolves every syntax', () {
      expect(
        ParserFactory.forSyntax(CommandSyntax.generic).syntax,
        CommandSyntax.generic,
      );
      expect(
        ParserFactory.forSyntax(CommandSyntax.posixShell).syntax,
        CommandSyntax.posixShell,
      );
      expect(
        ParserFactory.forSyntax(CommandSyntax.bash).syntax,
        CommandSyntax.bash,
      );
      expect(
        ParserFactory.forSyntax(CommandSyntax.windowsCmd).syntax,
        CommandSyntax.windowsCmd,
      );
      expect(
        ParserFactory.forSyntax(CommandSyntax.powershell).syntax,
        CommandSyntax.powershell,
      );
    });
  });

  group('ShellParser edge cases', () {
    const p = BashParser();
    test('lone dollar is literal', () {
      final inv = p.parse(r'echo $').ast! as CommandInvocation;
      expect(inv.arguments, [r'$']);
    });
    test('unterminated braced expansion warns', () {
      final r = p.parse(r'echo ${HOME');
      expect(r.diagnostics.any((d) => d.message.contains(r'${')), isTrue);
    });
    test(r'special parameter like $? is kept literally', () {
      final inv = p.parse(r'echo $?').ast! as CommandInvocation;
      expect(inv.environmentReferences, isEmpty);
    });
    test('chain operator with no following command warns', () {
      final r = p.parse('a &&');
      expect(r.diagnostics.any((d) => d.message.contains('Chain')), isTrue);
    });
    test('redirection-only command', () {
      final node = p.parse('> out.txt').ast;
      expect(node, isA<CommandInvocation>());
      expect((node! as CommandInvocation).redirections, hasLength(1));
    });
    test('escaped newline-adjacent operators in double quotes are literal', () {
      final inv = p.parse(r'echo "a;b|c"').ast! as CommandInvocation;
      expect(inv.arguments, ['a;b|c']);
    });
    test('append and error redirections', () {
      final inv = p.parse('cmd 1 2>> e >> o').ast! as CommandInvocation;
      final types = inv.redirections.map((r) => r.type).toSet();
      expect(types, contains(RedirectionType.appendErrorOutput));
      expect(types, contains(RedirectionType.appendOutput));
    });
    test('2 not followed by > is a normal token', () {
      final inv = p.parse('echo 2 things').ast! as CommandInvocation;
      expect(inv.arguments, ['2', 'things']);
    });
  });

  group('PowerShell edge cases', () {
    const p = PowerShellParser();
    test('lone dollar literal', () {
      final inv = p.parse(r'echo $').ast! as CommandInvocation;
      expect(inv.arguments, [r'$']);
    });
    test('append redirection', () {
      final inv = p.parse('echo hi >> log').ast! as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.appendOutput);
    });
    test('redirection without target tolerated', () {
      final r = p.parse('echo >');
      expect(r.ast, isNotNull);
    });
    test('unterminated double quote warns', () {
      final r = p.parse(r'echo "oops');
      expect(
        r.diagnostics.any((d) => d.severity == DiagnosticSeverity.warning),
        isTrue,
      );
    });
    test('unterminated subexpression warns', () {
      final r = p.parse(r'echo $(Get-Date');
      expect(
        r.diagnostics.any((d) => d.message.contains('subexpression')),
        isTrue,
      );
    });
    test('backtick at end of input', () {
      final inv = p.parse('echo a`').ast! as CommandInvocation;
      expect(inv.executable, 'echo');
    });
    test('call operator & acts as separator', () {
      final node = p.parse('& a; b').ast;
      expect(node, isA<CommandChain>());
    });
    test(r'$(...) inside double quotes', () {
      final inv = p.parse(r'echo "$(Get-Date)"').ast! as CommandInvocation;
      expect(inv.substitutions, hasLength(1));
    });
  });

  group('WindowsCmd edge cases', () {
    const p = WindowsCmdParser();
    test('redirection without target tolerated', () {
      final r = p.parse('echo >');
      expect(
        r.diagnostics.any((d) => d.message.contains('Redirection')),
        isTrue,
      );
    });
    test('input redirection', () {
      final inv = p.parse('sort < in.txt').ast! as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.input);
    });
    test('unterminated percent is literal', () {
      final inv = p.parse('echo %INCOMPLETE').ast! as CommandInvocation;
      expect(inv.environmentReferences, isEmpty);
    });
    test('pipeline then chain', () {
      final node = p.parse('a | b && c').ast;
      expect(node, isA<CommandChain>());
    });
  });
}
