import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  group('ParseDiagnostic', () {
    test('named constructors set severity', () {
      expect(const ParseDiagnostic.info('i').severity, DiagnosticSeverity.info);
      expect(
        const ParseDiagnostic.warning('w').severity,
        DiagnosticSeverity.warning,
      );
      expect(
        const ParseDiagnostic.error('e').severity,
        DiagnosticSeverity.error,
      );
    });
    test('equality, hashCode and toString', () {
      const a = ParseDiagnostic.warning('msg', offset: 3);
      const b = ParseDiagnostic.warning('msg', offset: 3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('warning'));
      expect(a.toString(), contains('msg'));
      expect(a, isNot(const ParseDiagnostic.error('msg', offset: 3)));
    });
  });

  group('ParseResult', () {
    test('exposes nodes, invocations, errors and toString', () {
      final result = const BashParser().parse('a && b | c');
      expect(result.isSuccess, isTrue);
      expect(result.hasErrors, isFalse);
      expect(result.allNodes, isNotEmpty);
      expect(result.invocations.map((i) => i.executable), ['a', 'b', 'c']);
      expect(result.toString(), contains('ParseResult'));
    });
    test('empty input has null ast and no nodes', () {
      final result = const BashParser().parse('');
      expect(result.isSuccess, isFalse);
      expect(result.allNodes, isEmpty);
      expect(result.invocations, isEmpty);
    });
  });

  group('SecurityFinding', () {
    test('equality, hashCode and toString', () {
      const a = SecurityFinding(
        level: SecurityLevel.highRisk,
        message: 'm',
        code: 'c',
        offset: 1,
      );
      const b = SecurityFinding(
        level: SecurityLevel.highRisk,
        message: 'm',
        code: 'c',
        offset: 1,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('highRisk'));
      expect(a.toString(), contains('c'));
      expect(
        a,
        isNot(
          const SecurityFinding(
            level: SecurityLevel.safe,
            message: 'm',
            code: 'c',
          ),
        ),
      );
    });
  });

  group('SecurityLevel ordering', () {
    test('isAtLeast and max', () {
      expect(SecurityLevel.critical.isAtLeast(SecurityLevel.safe), isTrue);
      expect(SecurityLevel.safe.isAtLeast(SecurityLevel.critical), isFalse);
      expect(
        SecurityLevel.lowRisk.max(SecurityLevel.highRisk),
        SecurityLevel.highRisk,
      );
      expect(
        SecurityLevel.highRisk.max(SecurityLevel.lowRisk),
        SecurityLevel.highRisk,
      );
    });
  });

  group('CommandDecision ordering', () {
    test('mostRestrictive', () {
      expect(
        CommandDecision.allow.mostRestrictive(CommandDecision.deny),
        CommandDecision.deny,
      );
      expect(
        CommandDecision.deny.mostRestrictive(CommandDecision.review),
        CommandDecision.deny,
      );
    });
  });

  group('CommandResult', () {
    test('toString and isAllowed', () {
      const r = CommandResult(
        decision: CommandDecision.review,
        securityLevel: SecurityLevel.mediumRisk,
        findings: [],
      );
      expect(r.isAllowed, isFalse);
      expect(r.toString(), contains('review'));
    });
    test('merge de-duplicates findings', () {
      const f = SecurityFinding(
        level: SecurityLevel.lowRisk,
        message: 'm',
        code: 'c',
      );
      const a = CommandResult(
        decision: CommandDecision.allow,
        securityLevel: SecurityLevel.lowRisk,
        findings: [f],
      );
      final merged = a.merge(a);
      expect(merged.findings, hasLength(1));
    });
  });

  group('CommandAnalysis', () {
    test('toString, hasParseErrors and invocations', () {
      final shield = CommandShield(defaultSyntax: CommandSyntax.bash);
      final analysis = shield.analyze('cat a | grep b');
      expect(analysis.toString(), contains('CommandAnalysis'));
      expect(analysis.hasParseErrors, isFalse);
      expect(analysis.invocations.map((i) => i.executable), ['cat', 'grep']);
      expect(analysis.normalizedExecutables, ['cat', 'grep']);
    });
  });

  group('AST toString coverage', () {
    test('every node type stringifies with its details', () {
      const inv = CommandInvocation(
        executable: 'cmd',
        arguments: ['a'],
        redirections: [
          RedirectionNode(type: RedirectionType.output, target: 'o'),
        ],
        substitutions: [
          CommandSubstitution(CommandInvocation(executable: 'x')),
        ],
        environmentReferences: [EnvironmentVariableReference('HOME')],
      );
      expect(
        inv.toString(),
        allOf(
          contains('cmd'),
          contains('redirs'),
          contains('subs'),
          contains('env'),
        ),
      );
      expect(
        const Pipeline([CommandInvocation(executable: 'a')]).toString(),
        contains('Pipeline'),
      );
      expect(
        const CommandChain(
          commands: [CommandInvocation(executable: 'a')],
          operator: ChainOperator.or,
        ).toString(),
        contains('or'),
      );
      expect(
        const RedirectionNode(
          type: RedirectionType.input,
          target: 't',
        ).toString(),
        contains('input'),
      );
      expect(
        const CommandSubstitution(
          CommandInvocation(executable: 'x'),
        ).toString(),
        contains('CommandSubstitution'),
      );
      expect(const EnvironmentVariableReference('P').toString(), contains('P'));
      // Inequality branches.
      expect(
        const Pipeline([CommandInvocation(executable: 'a')]),
        isNot(const Pipeline([CommandInvocation(executable: 'b')])),
      );
      expect(
        const RedirectionNode(type: RedirectionType.input, target: 't'),
        isNot(const RedirectionNode(type: RedirectionType.output, target: 't')),
      );
    });
  });

  group('QuoteAwareSplitter', () {
    const splitter = QuoteAwareSplitter();
    test('double quotes with escapes', () {
      expect(splitter.split(r'echo "a\"b"'), ['echo', 'a"b']);
      expect(splitter.split(r'"a\\b"'), [r'a\b']);
    });
    test('unterminated double quote invokes onError', () {
      var called = false;
      final words = splitter.split(
        'echo "oops',
        onError: (m, o) {
          called = true;
        },
      );
      expect(called, isTrue);
      expect(words, ['echo', 'oops']);
    });
    test('adjacent quoted and unquoted segments join', () {
      expect(splitter.split('a"b"c'), ['abc']);
    });
  });
}
