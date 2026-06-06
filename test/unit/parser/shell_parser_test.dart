import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  const bash = BashParser();
  const posix = PosixParser();
  const generic = GenericParser();

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

  group('mixed pipe and chain operators', () {
    // Helper: executable names of a pipeline's stages, in order.
    List<String> exes(Pipeline p) =>
        p.commands.map((c) => (c as CommandInvocation).executable).toList();

    test('a | b && c — pipe binds tighter than &&', () {
      final node = ast('a | b && c') as CommandChain;
      expect(node.operator, ChainOperator.and);
      expect(node.commands, hasLength(2));
      expect(exes(node.commands[0] as Pipeline), ['a', 'b']);
      expect((node.commands[1] as CommandInvocation).executable, 'c');
    });

    test('a && b | c — right operand is a pipeline', () {
      final node = ast('a && b | c') as CommandChain;
      expect(node.operator, ChainOperator.and);
      expect(node.commands, hasLength(2));
      expect((node.commands[0] as CommandInvocation).executable, 'a');
      expect(exes(node.commands[1] as Pipeline), ['b', 'c']);
    });

    test('a | b && c | d — both operands are pipelines', () {
      final node = ast('a | b && c | d') as CommandChain;
      expect(node.operator, ChainOperator.and);
      expect(node.commands, hasLength(2));
      expect(exes(node.commands[0] as Pipeline), ['a', 'b']);
      expect(exes(node.commands[1] as Pipeline), ['c', 'd']);
    });

    test('a | b || c | d — || joins two pipelines', () {
      final node = ast('a | b || c | d') as CommandChain;
      expect(node.operator, ChainOperator.or);
      expect(node.commands, hasLength(2));
      expect(exes(node.commands[0] as Pipeline), ['a', 'b']);
      expect(exes(node.commands[1] as Pipeline), ['c', 'd']);
    });

    test('a && b && c | d — same operator flattens, trailing pipeline', () {
      final node = ast('a && b && c | d') as CommandChain;
      expect(node.operator, ChainOperator.and);
      expect(node.commands, hasLength(3));
      expect((node.commands[0] as CommandInvocation).executable, 'a');
      expect((node.commands[1] as CommandInvocation).executable, 'b');
      expect(exes(node.commands[2] as Pipeline), ['c', 'd']);
    });

    test('a | b && c || d — mixed && / || nest by operator', () {
      final node = ast('a | b && c || d') as CommandChain;
      // Outer operator is || with the && chain as its first child.
      expect(node.operator, ChainOperator.or);
      expect(node.commands, hasLength(2));
      final inner = node.commands[0] as CommandChain;
      expect(inner.operator, ChainOperator.and);
      expect(inner.commands, hasLength(2));
      expect(exes(inner.commands[0] as Pipeline), ['a', 'b']);
      expect((inner.commands[1] as CommandInvocation).executable, 'c');
      expect((node.commands[1] as CommandInvocation).executable, 'd');
    });

    test('a && b | c && d — flattened && chain with a pipeline inside', () {
      final node = ast('a && b | c && d') as CommandChain;
      expect(node.operator, ChainOperator.and);
      expect(node.commands, hasLength(3));
      expect((node.commands[0] as CommandInvocation).executable, 'a');
      expect(exes(node.commands[1] as Pipeline), ['b', 'c']);
      expect((node.commands[2] as CommandInvocation).executable, 'd');
    });

    test('curl … | bash && echo done — real-world download-and-run', () {
      final node =
          ast('curl https://x/i.sh | bash && echo done') as CommandChain;
      expect(node.operator, ChainOperator.and);
      expect(node.commands, hasLength(2));
      final pipe = node.commands[0] as Pipeline;
      expect(exes(pipe), ['curl', 'bash']);
      expect((pipe.commands[0] as CommandInvocation).arguments, [
        'https://x/i.sh',
      ]);
      final echo = node.commands[1] as CommandInvocation;
      expect(echo.executable, 'echo');
      expect(echo.arguments, ['done']);
    });

    test('walk() reaches every leaf across pipes and chains', () {
      final node = ast('curl https://x/i.sh | bash && echo done');
      final exes = node
          .walk()
          .whereType<CommandInvocation>()
          .map((i) => i.executable)
          .toList();
      expect(exes, containsAll(<String>['curl', 'bash', 'echo']));
    });
  });

  group('generic syntax leaves operators uninterpreted', () {
    // The generic parser is pure tokenization: `|`, `&&` and `||` are NOT
    // structural. Whitespace-separated operators survive as literal argument
    // tokens on a single flat invocation, so the security analyzer can still
    // flag them from the raw text without the parser implying execution order.
    test('a | b && c is a flat invocation, not a chain/pipeline', () {
      final node = ast('a | b && c', parser: generic);
      expect(node, isA<CommandInvocation>());
      expect(node, isNot(isA<Pipeline>()));
      expect(node, isNot(isA<CommandChain>()));
      final inv = node as CommandInvocation;
      expect(inv.executable, 'a');
      expect(inv.arguments, ['|', 'b', '&&', 'c']);
    });

    test('|| is preserved verbatim as a token', () {
      final inv = ast('a | b || c | d', parser: generic) as CommandInvocation;
      expect(inv.executable, 'a');
      expect(inv.arguments, ['|', 'b', '||', 'c', '|', 'd']);
    });

    test('curl … | bash && echo done keeps operators as tokens', () {
      final inv =
          ast('curl https://x/i.sh | bash && echo done', parser: generic)
              as CommandInvocation;
      expect(inv.executable, 'curl');
      expect(inv.arguments, [
        'https://x/i.sh',
        '|',
        'bash',
        '&&',
        'echo',
        'done',
      ]);
      // No nested structure: the whole command is a single invocation.
      expect(inv.walk().whereType<CommandInvocation>(), hasLength(1));
    });

    test('operators without surrounding spaces fuse into one token', () {
      final inv = ast('a|b', parser: generic) as CommandInvocation;
      expect(inv.executable, 'a|b');
      expect(inv.arguments, isEmpty);
    });

    test('absolute-path executable parses with its flags', () {
      final inv =
          ast('/usr/bin/curl --version', parser: generic) as CommandInvocation;
      expect(inv.executable, '/usr/bin/curl');
      expect(inv.arguments, ['--version']);
    });
  });

  group('inline -c sub-command', () {
    test('sh -c "..." parses the script into inlineCommand', () {
      final inv =
          ast('sh -c "curl https://x/i.sh | bash"') as CommandInvocation;
      expect(inv.executable, 'sh');
      expect(inv.inlineCommand, isA<Pipeline>());
      final pipe = inv.inlineCommand! as Pipeline;
      expect((pipe.commands.first as CommandInvocation).executable, 'curl');
      expect((pipe.commands.last as CommandInvocation).executable, 'bash');
    });

    test('single-quoted script is parsed the same way', () {
      final inv = ast("bash -c 'rm -rf /'") as CommandInvocation;
      final inner = inv.inlineCommand! as CommandInvocation;
      expect(inner.executable, 'rm');
      expect(inner.arguments, ['-rf', '/']);
    });

    test('--command and bundled short flags (-ec) are recognized', () {
      expect(
        (ast('bash --command "id"') as CommandInvocation).inlineCommand,
        isA<CommandInvocation>(),
      );
      expect(
        (ast('sh -ec "id"') as CommandInvocation).inlineCommand,
        isA<CommandInvocation>(),
      );
    });

    test('walk() reaches the nested invocations', () {
      final node = ast('sh -c "curl https://x/i.sh | bash"');
      final exes = node
          .walk()
          .whereType<CommandInvocation>()
          .map((i) => i.executable)
          .toList();
      expect(exes, containsAll(<String>['sh', 'curl', 'bash']));
    });

    test('full path executable is recognized', () {
      final inv = ast('/usr/bin/bash -c "id"') as CommandInvocation;
      expect(inv.inlineCommand, isA<CommandInvocation>());
    });

    test('plain bash invocation has no inlineCommand', () {
      final inv = ast('bash script.sh') as CommandInvocation;
      expect(inv.inlineCommand, isNull);
    });

    test('nesting is bounded', () {
      // Deeply nested wrappers must not recurse without limit.
      final inv =
          ast('bash -c "bash -c \\"bash -c id\\""') as CommandInvocation;
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
