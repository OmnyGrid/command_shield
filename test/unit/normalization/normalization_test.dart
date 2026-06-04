import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  final normalizer = Normalizer.standard();

  group('Normalizer default rules', () {
    test('strips unix directory', () {
      expect(normalizer.normalize('/bin/rm'), 'rm');
      expect(normalizer.normalize('/usr/local/bin/dart'), 'dart');
    });

    test('strips windows directory', () {
      expect(normalizer.normalize(r'C:\Windows\System32\cmd.exe'), 'cmd');
    });

    test('strips windows extension', () {
      expect(normalizer.normalize('powershell.exe'), 'powershell');
      expect(normalizer.normalize('setup.cmd'), 'setup');
      expect(normalizer.normalize('run.bat'), 'run');
    });

    test('collapses version suffix for known interpreters', () {
      expect(normalizer.normalize('python3'), 'python');
      expect(normalizer.normalize('python2.7'), 'python');
      expect(normalizer.normalize('pip3'), 'pip');
      expect(normalizer.normalize('node18'), 'node');
    });

    test('does not collapse version for unknown names', () {
      expect(normalizer.normalize('foo2'), 'foo2');
    });

    test('resolves aliases', () {
      expect(normalizer.normalize('pwsh'), 'powershell');
      expect(normalizer.normalize('vi'), 'vim');
    });

    test('trims whitespace', () {
      expect(normalizer.normalize('  ls  '), 'ls');
    });

    test('combined: path + extension + alias', () {
      expect(normalizer.normalize(r'C:\tools\pwsh.exe'), 'powershell');
    });

    test('passes through already-canonical names', () {
      expect(normalizer.normalize('git'), 'git');
    });
  });

  group('extensibility', () {
    test('withRules appends custom rules', () {
      final custom = normalizer.withRules([
        NormalizationRule(
          name: 'kubectl-alias',
          description: 'k -> kubectl',
          apply: (e) => e == 'k' ? 'kubectl' : e,
        ),
      ]);
      expect(custom.normalize('k'), 'kubectl');
      // Original rules still apply.
      expect(custom.normalize('/bin/rm'), 'rm');
    });

    test('individual rule objects expose metadata', () {
      expect(stripDirectoryRule.name, 'strip-directory');
      expect(stripWindowsExtensionRule.description, isNotEmpty);
    });

    test('default rule list is complete and unmodifiable', () {
      expect(defaultNormalizationRules, hasLength(4));
      expect(
        () => defaultNormalizationRules.add(stripDirectoryRule),
        throwsUnsupportedError,
      );
    });
  });
}
