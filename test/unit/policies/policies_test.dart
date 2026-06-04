import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  // A shield with no policy attached, used only to produce analyses for the
  // policies under test.
  final shield = CommandShield(defaultSyntax: CommandSyntax.bash);

  CommandAnalysis analyze(String raw, {CommandSyntax? syntax}) =>
      shield.analyze(raw, syntax: syntax);

  group('DangerousCharacterPolicy', () {
    const policy = DangerousCharacterPolicy();
    test('denies pipes and chaining', () {
      expect(policy.evaluate(analyze('a | b')).decision, CommandDecision.deny);
      expect(policy.evaluate(analyze('a && b')).decision, CommandDecision.deny);
    });
    test('allows a clean command', () {
      expect(
        policy.evaluate(analyze('git status')).decision,
        CommandDecision.allow,
      );
    });
    test('configurable decision', () {
      const review = DangerousCharacterPolicy(onMatch: CommandDecision.review);
      expect(
        review.evaluate(analyze('a | b')).decision,
        CommandDecision.review,
      );
    });
    test('custom forbidden set', () {
      const custom = DangerousCharacterPolicy(forbidden: {'@'});
      expect(custom.evaluate(analyze('a | b')).decision, CommandDecision.allow);
      expect(
        custom.evaluate(analyze('mail a@b')).decision,
        CommandDecision.deny,
      );
    });
  });

  group('ExecutableAllowListPolicy', () {
    final policy = ExecutableAllowListPolicy({'git', 'dart'});
    test('allows listed executables', () {
      expect(
        policy.evaluate(analyze('git status')).decision,
        CommandDecision.allow,
      );
    });
    test('denies unlisted executables', () {
      expect(policy.evaluate(analyze('rm x')).decision, CommandDecision.deny);
    });
    test('matches normalized names', () {
      expect(
        policy.evaluate(analyze('/usr/bin/git status')).decision,
        CommandDecision.allow,
      );
    });
    test('empty command is allowed (nothing to violate)', () {
      expect(policy.evaluate(analyze('')).decision, CommandDecision.allow);
    });
    test('configurable violation decision', () {
      final review = ExecutableAllowListPolicy({
        'git',
      }, onViolation: CommandDecision.review);
      expect(review.evaluate(analyze('rm x')).decision, CommandDecision.review);
    });
  });

  group('ExecutableBlockListPolicy', () {
    final policy = ExecutableBlockListPolicy({'rm', 'curl'});
    test('denies blocked executables', () {
      expect(policy.evaluate(analyze('rm x')).decision, CommandDecision.deny);
    });
    test('allows non-blocked executables', () {
      expect(
        policy.evaluate(analyze('git status')).decision,
        CommandDecision.allow,
      );
    });
    test('matches through path normalization', () {
      expect(
        policy.evaluate(analyze('/bin/rm x')).decision,
        CommandDecision.deny,
      );
    });
  });

  group('ArgumentPatternPolicy', () {
    test('denies matching argument', () {
      final policy = ArgumentPatternPolicy(pattern: RegExp(r'^--force$'));
      expect(
        policy.evaluate(analyze('git push --force')).decision,
        CommandDecision.deny,
      );
    });
    test('allows when no argument matches', () {
      final policy = ArgumentPatternPolicy(pattern: RegExp(r'secret'));
      expect(
        policy.evaluate(analyze('git status')).decision,
        CommandDecision.allow,
      );
    });
    test('matchWholeCommand mode', () {
      final policy = ArgumentPatternPolicy(
        pattern: RegExp(r'token=\w+'),
        matchWholeCommand: true,
      );
      expect(
        policy.evaluate(analyze('deploy token=abc')).decision,
        CommandDecision.deny,
      );
    });
    test('false-positive prevention: unrelated text', () {
      final policy = ArgumentPatternPolicy(pattern: RegExp(r'rm -rf'));
      expect(
        policy.evaluate(analyze('echo hello')).decision,
        CommandDecision.allow,
      );
    });
  });

  group('PathTraversalPolicy', () {
    const policy = PathTraversalPolicy();
    test('reviews traversal', () {
      expect(
        policy.evaluate(analyze('cat ../../x')).decision,
        CommandDecision.review,
      );
    });
    test('allows clean paths', () {
      expect(
        policy.evaluate(analyze('cat a/b')).decision,
        CommandDecision.allow,
      );
    });
    test('bare .. ignored unless opted in', () {
      expect(policy.evaluate(analyze('cd ..')).decision, CommandDecision.allow);
      const strict = PathTraversalPolicy(includeBareParentReference: true);
      expect(
        strict.evaluate(analyze('cd ..')).decision,
        CommandDecision.review,
      );
    });
  });

  group('LengthLimitPolicy', () {
    test('reviews over-long commands', () {
      const policy = LengthLimitPolicy(maxLength: 5);
      expect(
        policy.evaluate(analyze('echo hello world')).decision,
        CommandDecision.review,
      );
    });
    test('allows short commands', () {
      const policy = LengthLimitPolicy(maxLength: 100);
      expect(policy.evaluate(analyze('ls')).decision, CommandDecision.allow);
    });
    test('boundary: exactly at limit is allowed', () {
      const policy = LengthLimitPolicy(maxLength: 2);
      expect(policy.evaluate(analyze('ls')).decision, CommandDecision.allow);
    });
  });

  group('EnvironmentVariableExpansionPolicy', () {
    const policy = EnvironmentVariableExpansionPolicy();
    test('reviews env expansion', () {
      expect(
        policy.evaluate(analyze(r'echo $HOME')).decision,
        CommandDecision.review,
      );
    });
    test('allows without env expansion', () {
      expect(
        policy.evaluate(analyze('echo hi')).decision,
        CommandDecision.allow,
      );
    });
  });

  group('ShellExecutionPolicy', () {
    const policy = ShellExecutionPolicy();
    test('denies bash -c by default', () {
      expect(
        policy.evaluate(analyze('bash -c "ls"')).decision,
        CommandDecision.deny,
      );
    });
    test('allows plain command', () {
      expect(policy.evaluate(analyze('ls')).decision, CommandDecision.allow);
    });
    test('configurable decision', () {
      const review = ShellExecutionPolicy(onMatch: CommandDecision.review);
      expect(
        review.evaluate(analyze('bash -c x')).decision,
        CommandDecision.review,
      );
    });
  });

  group('RiskThresholdPolicy', () {
    const policy = RiskThresholdPolicy();
    test('safe -> allow', () {
      expect(
        policy.evaluate(analyze('git status')).decision,
        CommandDecision.allow,
      );
    });
    test('high risk -> review', () {
      expect(
        policy.evaluate(analyze('rm -rf build')).decision,
        CommandDecision.review,
      );
    });
    test('critical -> deny', () {
      expect(
        policy.evaluate(analyze('rm -rf /')).decision,
        CommandDecision.deny,
      );
    });
    test('custom thresholds', () {
      const strict = RiskThresholdPolicy(
        reviewAt: SecurityLevel.lowRisk,
        denyAt: SecurityLevel.highRisk,
      );
      expect(
        strict.evaluate(analyze('rm -rf build')).decision,
        CommandDecision.deny,
      );
    });
  });

  group('PolicySet composition', () {
    test('takes the most restrictive decision', () {
      const set = PolicySet([RiskThresholdPolicy(), ShellExecutionPolicy()]);
      // shell-execution denies even though risk alone would only review.
      expect(
        set.evaluate(analyze('bash -c "ls"')).decision,
        CommandDecision.deny,
      );
    });
    test('empty-ish set allows safe command', () {
      const set = PolicySet([RiskThresholdPolicy()]);
      expect(
        set.evaluate(analyze('git status')).decision,
        CommandDecision.allow,
      );
    });
    test('add() returns an extended set', () {
      const base = PolicySet([RiskThresholdPolicy()]);
      final extended = base.add(ExecutableBlockListPolicy({'git'}));
      expect(
        extended.evaluate(analyze('git status')).decision,
        CommandDecision.deny,
      );
    });
    test('merges and de-duplicates findings', () {
      const set = PolicySet([RiskThresholdPolicy(), RiskThresholdPolicy()]);
      final result = set.evaluate(analyze('rm -rf /'));
      expect(result.decision, CommandDecision.deny);
    });
  });

  group('CommandResult', () {
    test('merge takes most restrictive decision and max level', () {
      const a = CommandResult(
        decision: CommandDecision.allow,
        securityLevel: SecurityLevel.lowRisk,
        findings: [],
      );
      const b = CommandResult(
        decision: CommandDecision.deny,
        securityLevel: SecurityLevel.critical,
        findings: [],
      );
      final merged = a.merge(b);
      expect(merged.decision, CommandDecision.deny);
      expect(merged.securityLevel, SecurityLevel.critical);
    });
    test('allow constructor', () {
      const r = CommandResult.allow();
      expect(r.isAllowed, isTrue);
    });
  });
}
