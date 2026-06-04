import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  group('AST node construction & equality', () {
    test('CommandInvocation', () {
      const a = CommandInvocation(executable: 'git', arguments: ['status']);
      const b = CommandInvocation(executable: 'git', arguments: ['status']);
      const c = CommandInvocation(executable: 'git', arguments: ['log']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.tokens, ['git', 'status']);
      expect(a.children, isEmpty);
      expect(a.toString(), contains('git'));
    });

    test('Pipeline', () {
      const p = Pipeline([
        CommandInvocation(executable: 'cat'),
        CommandInvocation(executable: 'grep'),
      ]);
      expect(p.commands, hasLength(2));
      expect(p.children, hasLength(2));
      expect(
        p,
        const Pipeline([
          CommandInvocation(executable: 'cat'),
          CommandInvocation(executable: 'grep'),
        ]),
      );
    });

    test('CommandChain', () {
      const chain = CommandChain(
        commands: [
          CommandInvocation(executable: 'a'),
          CommandInvocation(executable: 'b'),
        ],
        operator: ChainOperator.and,
      );
      expect(chain.operator, ChainOperator.and);
      expect(chain.children, hasLength(2));
      expect(
        chain,
        const CommandChain(
          commands: [
            CommandInvocation(executable: 'a'),
            CommandInvocation(executable: 'b'),
          ],
          operator: ChainOperator.and,
        ),
      );
      expect(chain.hashCode, isA<int>());
    });

    test('CommandScript', () {
      const script = CommandScript([
        CommandInvocation(executable: 'a'),
        CommandInvocation(executable: 'b'),
      ]);
      expect(script.commands, hasLength(2));
      expect(script.children, hasLength(2));
      expect(script.toString(), contains('CommandScript'));
    });

    test('RedirectionNode', () {
      const r = RedirectionNode(
        type: RedirectionType.appendOutput,
        target: 'log',
      );
      expect(r.type, RedirectionType.appendOutput);
      expect(r.target, 'log');
      expect(r.children, isEmpty);
      expect(
        r,
        const RedirectionNode(
          type: RedirectionType.appendOutput,
          target: 'log',
        ),
      );
    });

    test('CommandSubstitution', () {
      const s = CommandSubstitution(CommandInvocation(executable: 'whoami'));
      expect(s.command, isA<CommandInvocation>());
      expect(s.children, hasLength(1));
      expect(
        s,
        const CommandSubstitution(CommandInvocation(executable: 'whoami')),
      );
    });

    test('EnvironmentVariableReference', () {
      const e = EnvironmentVariableReference('HOME');
      expect(e.variable, 'HOME');
      expect(e.children, isEmpty);
      expect(e, const EnvironmentVariableReference('HOME'));
      expect(e.hashCode, 'HOME'.hashCode);
    });

    test('walk visits nested structure depth-first', () {
      const tree = CommandChain(
        commands: [
          Pipeline([
            CommandInvocation(executable: 'cat'),
            CommandInvocation(executable: 'grep'),
          ]),
          CommandInvocation(executable: 'echo'),
        ],
        operator: ChainOperator.and,
      );
      final invocations = tree.walk().whereType<CommandInvocation>().map(
        (i) => i.executable,
      );
      expect(invocations, ['cat', 'grep', 'echo']);
    });
  });
}
