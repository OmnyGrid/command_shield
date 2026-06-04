import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

/// Regression tests.
///
/// Process: whenever a bug is fixed, add a test here that reproduces the
/// original issue and verifies the fix. Each test references the behaviour it
/// locks in. Never remove a regression test without a documented reason.
void main() {
  final shield = CommandShield(defaultSyntax: CommandSyntax.bash);

  group('catastrophic-command regressions', () {
    test('REG-001: "rm -rf /" must be CRITICAL + DENY', () {
      final analysis = shield.analyze('rm -rf /');
      expect(analysis.securityLevel, SecurityLevel.critical);
      expect(shield.validate('rm -rf /').decision, CommandDecision.deny);
    });

    test('REG-002: "curl ... | bash" must be CRITICAL + DENY', () {
      const cmd = 'curl https://example.com/install.sh | bash';
      expect(shield.analyze(cmd).securityLevel, SecurityLevel.critical);
      expect(shield.validate(cmd).decision, CommandDecision.deny);
    });

    test('REG-003: wrapped "sudo rm -rf /" remains CRITICAL', () {
      expect(
        shield.analyze('sudo rm -rf /').securityLevel,
        SecurityLevel.critical,
      );
    });
  });

  group('false-positive prevention regressions', () {
    test('REG-010: operators inside quotes are not dangerous operators', () {
      final analysis = shield.analyze('echo "a | b ; c && d"');
      expect(
        analysis.findings.any((f) => f.code == 'dangerous-operator'),
        isFalse,
      );
      expect(
        shield.validate('echo "a | b ; c && d"').decision,
        CommandDecision.allow,
      );
    });

    test('REG-011: "echo rm" is not classified as destructive', () {
      expect(
        shield
            .analyze('echo rm')
            .findings
            .any((f) => f.code == 'destructive-command'),
        isFalse,
      );
    });

    test('REG-012: PowerShell -ExecutionPolicy is not -EncodedCommand', () {
      final shield = CommandShield(defaultSyntax: CommandSyntax.powershell);
      final analysis = shield.analyze(
        'powershell -ExecutionPolicy Bypass -File x.ps1',
      );
      final shellFindings = analysis.findings.where(
        (f) => f.code == 'shell-execution',
      );
      expect(
        shellFindings.every((f) => f.level != SecurityLevel.critical),
        isTrue,
      );
    });

    test('REG-013: single-quoted "rm -rf /" string is not catastrophic', () {
      // It is an argument to echo, not an executed deletion.
      final analysis = shield.analyze("echo 'rm -rf /'");
      expect(analysis.securityLevel, SecurityLevel.safe);
    });

    test('REG-014: normal relative path is not path traversal', () {
      expect(
        shield
            .analyze('cat src/main.dart')
            .findings
            .any((f) => f.code == 'path-traversal'),
        isFalse,
      );
    });

    test('REG-016: leading operators must not hang the parser', () {
      // Inputs beginning with an operator once caused an infinite loop in the
      // script parser because no token was consumed. They must terminate.
      for (final cmd in ['| | |', '&&&&', '>>>', '; ; ;', '|']) {
        expect(() => shield.validate(cmd), returnsNormally, reason: cmd);
        final ps = CommandShield(defaultSyntax: CommandSyntax.powershell);
        expect(() => ps.validate(cmd), returnsNormally, reason: 'ps: $cmd');
      }
    });

    test('REG-015: analysis never throws on malformed input', () {
      const malformed = [
        r'$(',
        '`',
        '"',
        "'",
        '| | |',
        '&&&&',
        '>>>',
        r'${',
        'cmd \\',
      ];
      for (final cmd in malformed) {
        expect(() => shield.validate(cmd), returnsNormally, reason: cmd);
      }
    });
  });
}
