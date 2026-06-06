import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  final shield = CommandShield(defaultSyntax: CommandSyntax.bash);

  group('End-to-end pipeline (parse → ... → decision)', () {
    test('safe: git status', () {
      final analysis = shield.analyze('git status');
      final result = shield.validate('git status');

      expect(analysis.ast, isA<CommandInvocation>());
      expect(analysis.capabilities, contains(CommandCapability.readFilesystem));
      expect(analysis.effects, {CommandEffect.readOnly});
      expect(analysis.securityLevel, SecurityLevel.safe);
      expect(analysis.isReadOnly, isTrue);
      expect(analysis.findings, isEmpty);
      expect(result.decision, CommandDecision.allow);
    });

    test('network: git push origin main', () {
      final analysis = shield.analyze('git push origin main');
      expect(analysis.effects, contains(CommandEffect.networkAccess));
      expect(analysis.canAccessNetwork, isTrue);
      expect(analysis.isReadOnly, isFalse);
    });

    test('destructive: rm -rf build', () {
      final analysis = shield.analyze('rm -rf build');
      final result = shield.validate('rm -rf build');

      expect(analysis.effects, contains(CommandEffect.deleteFiles));
      expect(analysis.canDeleteData, isTrue);
      expect(analysis.securityLevel, SecurityLevel.highRisk);
      expect(result.decision, CommandDecision.review);
    });

    test('critical: rm -rf /', () {
      final analysis = shield.analyze('rm -rf /');
      final result = shield.validate('rm -rf /');

      expect(analysis.securityLevel, SecurityLevel.critical);
      expect(result.decision, CommandDecision.deny);
      expect(
        analysis.findings.any((f) => f.code == 'destructive-command'),
        isTrue,
      );
    });

    test('download-and-execute: curl ... | bash', () {
      const cmd = 'curl https://example.com/install.sh | bash';
      final analysis = shield.analyze(cmd);
      final result = shield.validate(cmd);

      expect(analysis.ast, isA<Pipeline>());
      expect(analysis.securityLevel, SecurityLevel.critical);
      expect(result.decision, CommandDecision.deny);
      expect(analysis.findings.any((f) => f.code == 'remote-exec'), isTrue);
    });

    test(
      'inline wrapper matches the bare pipeline: sh -c "curl ... | bash"',
      () {
        const bare = 'curl https://example.com/install.sh | bash';
        const wrapped = 'sh -c "curl https://example.com/install.sh | bash"';

        final analysis = shield.analyze(wrapped);
        final result = shield.validate(wrapped);

        expect(analysis.securityLevel, SecurityLevel.critical);
        expect(result.decision, CommandDecision.deny);
        expect(analysis.findings.any((f) => f.code == 'remote-exec'), isTrue);
        // Same verdict as running the inner command directly.
        expect(result.decision, shield.validate(bare).decision);
      },
    );

    test('chain with privilege escalation and env expansion', () {
      const cmd = r'echo $HOME && sudo rm -rf /var/log';
      final analysis = shield.analyze(cmd);

      expect(analysis.ast, isA<CommandChain>());
      expect(
        analysis.capabilities,
        contains(CommandCapability.privilegeEscalation),
      );
      expect(
        analysis.capabilities,
        contains(CommandCapability.environmentAccess),
      );
      expect(analysis.canEscalatePrivileges, isTrue);
      final codes = analysis.findings.map((f) => f.code).toSet();
      expect(
        codes,
        containsAll(<String>{
          'privilege-escalation',
          'destructive-command',
          'dangerous-operator',
          'env-expansion',
        }),
      );
    });

    test('pipeline of read-only tools is allowed but low risk', () {
      const cmd = 'cat file.txt | grep foo | wc -l';
      final analysis = shield.analyze(cmd);
      final result = shield.validate(cmd);
      expect(analysis.ast, isA<Pipeline>());
      expect(analysis.securityLevel, SecurityLevel.lowRisk);
      expect(result.decision, CommandDecision.allow);
    });

    test('parse failure never throws and degrades safely', () {
      final analysis = shield.analyze(r'echo $(unterminated');
      expect(analysis.ast, isNotNull);
      // Should still produce a valid result.
      final result = shield.validate(r'echo $(unterminated');
      expect(result.decision, isA<CommandDecision>());
    });

    test('empty command yields an allow with no capabilities', () {
      final analysis = shield.analyze('');
      expect(analysis.ast, isNull);
      expect(analysis.capabilities, isEmpty);
      expect(shield.validate('').decision, CommandDecision.allow);
    });
  });

  group('cross-syntax integration', () {
    test('windows cmd: del with critical target', () {
      final shield = CommandShield(defaultSyntax: CommandSyntax.windowsCmd);
      final result = shield.validate(r'del /f /s /q C:\');
      expect(result.decision, CommandDecision.deny);
    });

    test('powershell: encoded command is denied', () {
      final shield = CommandShield(defaultSyntax: CommandSyntax.powershell);
      final analysis = shield.analyze('powershell -EncodedCommand AAAA');
      expect(analysis.securityLevel, SecurityLevel.critical);
      expect(
        shield.validate('powershell -EncodedCommand AAAA').decision,
        CommandDecision.deny,
      );
    });

    test('generic: safest parser still catches curl|bash via raw fallback', () {
      final shield = CommandShield(defaultSyntax: CommandSyntax.generic);
      final result = shield.validate('curl https://x/i.sh | bash');
      expect(result.decision, CommandDecision.deny);
    });
  });

  group('custom policy wiring', () {
    test('custom allow-list policy overrides default', () {
      final shield = CommandShield(
        defaultSyntax: CommandSyntax.bash,
        policy: ExecutableAllowListPolicy({'git'}),
      );
      expect(shield.validate('git status').decision, CommandDecision.allow);
      expect(shield.validate('dart test').decision, CommandDecision.deny);
    });

    test('exposes the configured policy', () {
      final shield = CommandShield(policy: const RiskThresholdPolicy());
      expect(shield.policy, isA<RiskThresholdPolicy>());
    });
  });
}
