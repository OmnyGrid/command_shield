import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  const bash = BashParser();
  const posix = PosixParser();

  CommandNode ast(String raw, {CommandParser parser = bash}) =>
      parser.parse(raw).ast!;

  group('ShellParser syntax', () {
    test('bash reports bash syntax', () {
      expect(bash.syntax, CommandSyntax.bash);
    });
    test('posix reports posixShell syntax', () {
      expect(posix.syntax, CommandSyntax.posixShell);
      // POSIX parser builds the same structures as bash.
      expect(posix.parse('a | b').ast, isA<Pipeline>());
    });
  });

  group('commands', () {
    test('simple invocation', () {
      final node = ast('git status') as CommandInvocation;
      expect(node.executable, 'git');
      expect(node.arguments, ['status']);
    });

    test('empty input', () {
      final result = bash.parse('');
      expect(result.ast, isNull);
    });
  });

  group('pipelines', () {
    test('two-stage pipeline', () {
      final node = ast('cat file.txt | grep foo') as Pipeline;
      expect(node.commands, hasLength(2));
      expect((node.commands[0] as CommandInvocation).executable, 'cat');
      expect((node.commands[1] as CommandInvocation).executable, 'grep');
    });

    test('three-stage pipeline', () {
      final node = ast('cat f | grep foo | wc -l') as Pipeline;
      expect(node.commands, hasLength(3));
    });

    test('pipe with no following command warns', () {
      final result = bash.parse('cat f |');
      expect(result.diagnostics.any((d) => d.message.contains('Pipe')), isTrue);
    });
  });

  group('chains', () {
    test('&& chain', () {
      final node = ast('git pull && dart test') as CommandChain;
      expect(node.operator, ChainOperator.and);
      expect(node.commands, hasLength(2));
    });

    test('|| chain', () {
      final node = ast('git pull || git clone repo') as CommandChain;
      expect(node.operator, ChainOperator.or);
    });

    test('; sequential chain flattens repeated operators', () {
      final node = ast('pwd ; ls ; git status') as CommandChain;
      expect(node.operator, ChainOperator.sequential);
      expect(node.commands, hasLength(3));
    });

    test('mixed operators nest by operator', () {
      final node = ast('a && b || c') as CommandChain;
      expect(node.operator, ChainOperator.or);
      expect(node.commands.first, isA<CommandChain>());
    });

    test('background & treated as sequential separator', () {
      final node = ast('a & b') as CommandChain;
      expect(node.operator, ChainOperator.sequential);
    });
  });

  group('scripts', () {
    test('newline-separated commands form a script', () {
      final node = ast('git status\ngit pull\ndart test') as CommandScript;
      expect(node.commands, hasLength(3));
    });

    test('blank lines are ignored', () {
      final node = ast('a\n\n\nb') as CommandScript;
      expect(node.commands, hasLength(2));
    });
  });

  group('redirections', () {
    test('output redirection', () {
      final inv = ast('echo hi > out.txt') as CommandInvocation;
      expect(inv.redirections, hasLength(1));
      expect(inv.redirections.first.type, RedirectionType.output);
      expect(inv.redirections.first.target, 'out.txt');
    });

    test('append redirection', () {
      final inv = ast('echo hi >> log') as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.appendOutput);
    });

    test('input redirection', () {
      final inv = ast('sort < data') as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.input);
    });

    test('here-document', () {
      final inv = ast('cat << EOF') as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.hereDocument);
    });

    test('stderr redirection 2>', () {
      final inv = ast('cmd 2> err.txt') as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.errorOutput);
    });

    test('stderr append 2>>', () {
      final inv = ast('cmd 2>> err.txt') as CommandInvocation;
      expect(inv.redirections.first.type, RedirectionType.appendErrorOutput);
    });

    test('redirection without target warns', () {
      final result = bash.parse('echo hi >');
      expect(
        result.diagnostics.any((d) => d.message.contains('Redirection')),
        isTrue,
      );
    });
  });

  group('command substitution', () {
    test(r'$(...) substitution', () {
      final inv = ast(r'echo $(whoami)') as CommandInvocation;
      expect(inv.substitutions, hasLength(1));
      final inner = inv.substitutions.first.command as CommandInvocation;
      expect(inner.executable, 'whoami');
    });

    test('nested parentheses are balanced', () {
      final inv = ast(r'echo $(echo $(date))') as CommandInvocation;
      expect(inv.substitutions, hasLength(1));
    });

    test('back-tick substitution', () {
      final inv = ast('echo `whoami`') as CommandInvocation;
      expect(inv.substitutions, hasLength(1));
    });

    test('unterminated substitution warns', () {
      final result = bash.parse(r'echo $(whoami');
      expect(
        result.diagnostics.any((d) => d.message.contains('substitution')),
        isTrue,
      );
    });
  });

  group('environment variables', () {
    test(r'$HOME reference', () {
      final inv = ast(r'echo $HOME') as CommandInvocation;
      expect(inv.environmentReferences.map((e) => e.variable), ['HOME']);
    });

    test(r'${HOME} braced reference', () {
      final inv = ast(r'echo ${HOME}') as CommandInvocation;
      expect(inv.environmentReferences.map((e) => e.variable), ['HOME']);
    });

    test(r'${VAR:-default} strips operators to bare name', () {
      final inv = ast(r'echo ${VAR:-x}') as CommandInvocation;
      expect(inv.environmentReferences.map((e) => e.variable), ['VAR']);
    });
  });

  group('quoting and escaping', () {
    test('single quotes are literal', () {
      final inv = ast(r"echo '$HOME | x'") as CommandInvocation;
      expect(inv.arguments, [r'$HOME | x']);
      expect(inv.environmentReferences, isEmpty);
      expect(inv.substitutions, isEmpty);
    });

    test('double quotes keep expansion active', () {
      final inv = ast(r'echo "$HOME"') as CommandInvocation;
      expect(inv.environmentReferences, hasLength(1));
    });

    test('escaped operator is literal', () {
      final inv = ast(r'echo a\|b') as CommandInvocation;
      expect(inv.arguments, ['a|b']);
    });

    test('unterminated single quote warns', () {
      final result = bash.parse("echo 'oops");
      expect(
        result.diagnostics.any((d) => d.severity == DiagnosticSeverity.warning),
        isTrue,
      );
    });
  });

  group('walk()', () {
    test('visits all nested nodes', () {
      final node = ast(r'a && b | c');
      expect(node.walk().whereType<CommandInvocation>().length, 3);
    });
  });
}
