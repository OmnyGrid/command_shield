import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  final kb = CommandKnowledgeBase();

  Set<CommandCapability> caps(String exe, List<String> args) =>
      kb.capabilitiesFor(exe, args);

  group('CommandKnowledgeBase sub-command refinement', () {
    test('git subcommands', () {
      expect(caps('git', ['push']), contains(CommandCapability.networkWrite));
      expect(caps('git', ['pull']), contains(CommandCapability.networkRead));
      expect(
        caps('git', ['commit']),
        contains(CommandCapability.writeFilesystem),
      );
      expect(caps('git', ['log']), contains(CommandCapability.readFilesystem));
    });

    test('docker push/pull/run', () {
      expect(
        caps('docker', ['push', 'img']),
        contains(CommandCapability.networkWrite),
      );
      final run = caps('docker', ['run', 'img']);
      expect(run, contains(CommandCapability.networkRead));
      expect(run, contains(CommandCapability.executePrograms));
    });

    test('npm/yarn/pnpm install and publish', () {
      final install = caps('npm', ['install']);
      expect(install, contains(CommandCapability.networkRead));
      expect(install, contains(CommandCapability.writeFilesystem));
      expect(
        caps('npm', ['publish']),
        contains(CommandCapability.networkWrite),
      );
      expect(
        caps('yarn', ['add', 'x']),
        contains(CommandCapability.networkRead),
      );
    });

    test('pip install', () {
      expect(
        caps('pip', ['install', 'x']),
        contains(CommandCapability.networkRead),
      );
    });

    test('apt/brew install touches system + network', () {
      final c = caps('apt-get', ['install', 'x']);
      expect(c, contains(CommandCapability.networkRead));
      expect(c, contains(CommandCapability.systemConfiguration));
    });

    test('curl upload flag implies network write', () {
      expect(
        caps('curl', ['-d', 'x', 'http://h']),
        contains(CommandCapability.networkWrite),
      );
      expect(
        caps('curl', ['-T', 'f', 'http://h']),
        contains(CommandCapability.networkWrite),
      );
    });

    test('ssh with remote command implies execute', () {
      expect(
        caps('ssh', ['host', 'ls']),
        contains(CommandCapability.executePrograms),
      );
    });

    test('sed -i implies write', () {
      expect(
        caps('sed', ['-i', 's/a/b/', 'f']),
        contains(CommandCapability.writeFilesystem),
      );
    });

    test('find -delete and -exec', () {
      expect(
        caps('find', ['.', '-delete']),
        contains(CommandCapability.deleteFilesystem),
      );
      expect(
        caps('find', ['.', '-exec', 'rm', '{}', ';']),
        contains(CommandCapability.executePrograms),
      );
    });

    test('scp and rsync are read + write network', () {
      final c = caps('scp', ['a', 'host:b']);
      expect(c, contains(CommandCapability.networkRead));
      expect(c, contains(CommandCapability.networkWrite));
    });

    test('dd reads and writes', () {
      final c = caps('dd', ['if=a', 'of=b']);
      expect(c, contains(CommandCapability.readFilesystem));
      expect(c, contains(CommandCapability.writeFilesystem));
    });

    test('env wrapper skips NAME=VALUE and finds wrapped command', () {
      final c = caps('env', ['FOO=bar', 'rm', '-rf', 'x']);
      expect(c, contains(CommandCapability.deleteFilesystem));
    });

    test('wrapper with only flags and no wrapped command', () {
      expect(
        caps('sudo', ['-k']),
        contains(CommandCapability.privilegeEscalation),
      );
    });

    test('env reference in argument implies environment access', () {
      expect(
        caps('echo', [r'$HOME']),
        contains(CommandCapability.environmentAccess),
      );
      expect(
        caps('echo', [r'%PATH%']),
        contains(CommandCapability.environmentAccess),
      );
    });

    test('unknown executable yields empty set', () {
      expect(caps('zzznotacommand', const []), isEmpty);
    });
  });
}
