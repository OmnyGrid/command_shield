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

  group('CommandKnowledgeBase.analyze', () {
    test('unknown command is not known and is safe', () {
      final r = kb.analyze('zzznotacommand', const []);
      expect(r.isKnown, isFalse);
      expect(r.knowledge, isNull);
      expect(r.capabilities, isEmpty);
      expect(r.risk, SecurityLevel.safe);
    });

    test('known command exposes its knowledge entry and category', () {
      final r = kb.analyze('git', const ['status']);
      expect(r.isKnown, isTrue);
      expect(r.knowledge!.executable, 'git');
      expect(r.knowledge!.category, KnowledgeCategory.versionControl);
    });

    test('git force push raises risk to medium with a note', () {
      final r = kb.analyze('git', const ['push', '--force', 'origin', 'main']);
      expect(r.capabilities, contains(CommandCapability.networkWrite));
      expect(r.risk, SecurityLevel.mediumRisk);
      expect(r.notes, isNotEmpty);
    });

    test('non-push force flag does not raise risk', () {
      final r = kb.analyze('git', const ['checkout', '-f', 'main']);
      expect(r.risk, SecurityLevel.safe);
      expect(r.capabilities, isNot(contains(CommandCapability.networkWrite)));
    });

    test('package install is flagged medium risk', () {
      expect(
        kb.analyze('npm', const ['install', 'x']).risk,
        SecurityLevel.mediumRisk,
      );
    });
  });

  group('subcommand matching skips leading flags', () {
    test('git --no-pager push is still a push', () {
      expect(
        caps('git', ['--no-pager', 'push']),
        contains(CommandCapability.networkWrite),
      );
    });

    test('docker --debug push is still a push', () {
      expect(
        caps('docker', ['--debug', 'push', 'img']),
        contains(CommandCapability.networkWrite),
      );
    });
  });

  group('newly covered commands', () {
    test('dart pub get reads network and writes files', () {
      final c = caps('dart', ['pub', 'get']);
      expect(c, contains(CommandCapability.networkRead));
      expect(c, contains(CommandCapability.writeFilesystem));
    });

    test('dart pub publish writes to the network', () {
      expect(
        caps('dart', ['pub', 'publish']),
        contains(CommandCapability.networkWrite),
      );
    });

    test('flutter run executes code', () {
      expect(
        caps('flutter', ['run']),
        contains(CommandCapability.executePrograms),
      );
    });

    test('tar reads and writes the filesystem', () {
      final c = caps('tar', ['-xzf', 'a.tgz']);
      expect(c, contains(CommandCapability.readFilesystem));
      expect(c, contains(CommandCapability.writeFilesystem));
    });

    test('md5sum reads the filesystem', () {
      expect(
        caps('md5sum', ['file']),
        contains(CommandCapability.readFilesystem),
      );
    });

    test('gzip reads and writes the filesystem', () {
      final c = caps('gzip', ['file']);
      expect(c, contains(CommandCapability.readFilesystem));
      expect(c, contains(CommandCapability.writeFilesystem));
    });

    test('openssl s_client uses the network', () {
      final c = caps('openssl', ['s_client', '-connect', 'host:443']);
      expect(c, contains(CommandCapability.networkRead));
      expect(c, contains(CommandCapability.networkWrite));
    });

    test('psql uses the network', () {
      final c = caps('psql', ['-h', 'db', '-c', 'select 1']);
      expect(c, contains(CommandCapability.networkRead));
      expect(c, contains(CommandCapability.networkWrite));
    });

    test('sqlite3 reads and writes a local database file', () {
      final c = caps('sqlite3', ['db.sqlite']);
      expect(c, contains(CommandCapability.readFilesystem));
      expect(c, contains(CommandCapability.writeFilesystem));
    });

    test('vim reads and writes the filesystem', () {
      final c = caps('vim', ['file']);
      expect(c, contains(CommandCapability.readFilesystem));
      expect(c, contains(CommandCapability.writeFilesystem));
    });

    test('docker push writes to the network', () {
      expect(
        caps('docker', ['push', 'img']),
        contains(CommandCapability.networkWrite),
      );
    });

    test('gh accesses the network', () {
      expect(
        caps('gh', ['pr', 'create']),
        contains(CommandCapability.networkRead),
      );
    });

    test('cargo build executes programs', () {
      expect(
        caps('cargo', ['build']),
        contains(CommandCapability.executePrograms),
      );
    });
  });

  group('disk and dangerous-system coverage', () {
    test('mkfs reports destructive caps and is critical', () {
      final c = caps('mkfs', ['/dev/sda']);
      expect(c, contains(CommandCapability.writeFilesystem));
      expect(c, contains(CommandCapability.deleteFilesystem));
      expect(c, contains(CommandCapability.systemConfiguration));
      expect(kb.analyze('mkfs', const []).risk, SecurityLevel.critical);
      expect(kb.analyze('mkfs.ext4', const []).risk, SecurityLevel.critical);
    });

    test('wipefs / blkdiscard are critical', () {
      expect(kb.analyze('wipefs', const []).risk, SecurityLevel.critical);
      expect(kb.analyze('blkdiscard', const []).risk, SecurityLevel.critical);
    });

    test('srm/wipe are delete + highRisk', () {
      expect(caps('srm', ['f']), contains(CommandCapability.deleteFilesystem));
      expect(kb.analyze('srm', const ['f']).risk, SecurityLevel.highRisk);
    });

    test('dd refine: device write escalates, file copy stays at floor', () {
      final dev = kb.analyze('dd', const ['if=/dev/zero', 'of=/dev/sda']);
      expect(dev.capabilities, contains(CommandCapability.systemConfiguration));
      expect(dev.risk, SecurityLevel.critical);
      // A plain file copy must not escalate.
      final file = kb.analyze('dd', const ['if=in.img', 'of=out.img']);
      expect(file.risk, SecurityLevel.safe);
      expect(
        file.capabilities,
        isNot(contains(CommandCapability.systemConfiguration)),
      );
    });

    test('partitioners and power tools are highRisk', () {
      expect(
        kb.analyze('fdisk', const ['/dev/sda']).risk,
        SecurityLevel.highRisk,
      );
      expect(
        kb.analyze('shutdown', const ['now']).risk,
        SecurityLevel.highRisk,
      );
      expect(
        caps('shutdown', ['now']),
        containsAll(const [
          CommandCapability.systemConfiguration,
          CommandCapability.processManagement,
        ]),
      );
      expect(
        kb.analyze('modprobe', const ['kvm']).risk,
        SecurityLevel.highRisk,
      );
    });

    test('csrutil disable is critical, status stays highRisk', () {
      expect(
        kb.analyze('csrutil', const ['disable']).risk,
        SecurityLevel.critical,
      );
      expect(
        kb.analyze('csrutil', const ['status']).risk,
        SecurityLevel.highRisk,
      );
    });

    test('diskutil erase verbs are critical, list stays highRisk', () {
      expect(
        kb.analyze('diskutil', const ['eraseDisk', 'JHFS+', 'X', 'disk2']).risk,
        SecurityLevel.critical,
      );
      expect(
        kb.analyze('diskutil', const ['list']).risk,
        SecurityLevel.highRisk,
      );
    });
  });

  group('Phase 1 breadth coverage', () {
    test('network inspection tools read the network', () {
      for (final c in const ['nmap', 'ip', 'ss', 'netstat', 'tcpdump', 'mtr']) {
        expect(
          caps(c, const []),
          contains(CommandCapability.networkRead),
          reason: c,
        );
      }
    });

    test('modern read-only CLIs do not write by default', () {
      for (final c in const ['jq', 'rg', 'fd', 'bat', 'eza', 'delta']) {
        final c0 = caps(c, const []);
        expect(c0, contains(CommandCapability.readFilesystem), reason: c);
        expect(
          c0,
          isNot(contains(CommandCapability.writeFilesystem)),
          reason: c,
        );
      }
      // jq -i edits in place.
      expect(
        caps('jq', const ['-i', '.x', 'f.json']),
        contains(CommandCapability.writeFilesystem),
      );
    });

    test('vcs tools mirror git read/write/network split', () {
      expect(
        caps('hg', const ['push']),
        contains(CommandCapability.networkWrite),
      );
      expect(
        caps('hg', const ['pull']),
        contains(CommandCapability.networkRead),
      );
      expect(
        caps('svn', const ['commit']),
        contains(CommandCapability.writeFilesystem),
      );
      expect(
        caps('hg', const ['status']),
        contains(CommandCapability.readFilesystem),
      );
    });

    test('IaC tools provision over the network and run code', () {
      // Provisioners are read-only until an apply/up verb; ansible-playbook
      // configures hosts on every run.
      for (final entry in const [
        ['terraform', 'apply'],
        ['pulumi', 'up'],
        ['ansible-playbook', 'site.yml'],
      ]) {
        final c0 = caps(entry[0], [entry[1]]);
        expect(c0, contains(CommandCapability.networkWrite), reason: entry[0]);
        expect(
          c0,
          contains(CommandCapability.executePrograms),
          reason: entry[0],
        );
      }
    });

    test('new package managers install / publish', () {
      expect(
        caps('bun', const ['install']),
        contains(CommandCapability.networkRead),
      );
      expect(
        caps('uv', const ['add', 'x']),
        contains(CommandCapability.networkRead),
      );
      expect(
        caps('nix', const ['install', 'x']),
        contains(CommandCapability.systemConfiguration),
      );
      expect(
        caps('twine', const ['upload']),
        contains(CommandCapability.networkWrite),
      );
    });

    test('cloud / sync clients reach the network', () {
      expect(caps('doctl', const []), contains(CommandCapability.networkWrite));
      final rclone = caps('rclone', const []);
      expect(rclone, contains(CommandCapability.networkRead));
      expect(rclone, contains(CommandCapability.readFilesystem));
    });

    test('process/log inspection tools', () {
      expect(
        caps('lsof', const []),
        contains(CommandCapability.processManagement),
      );
      expect(
        caps('dmesg', const []),
        contains(CommandCapability.readFilesystem),
      );
    });

    test('container builders and tools', () {
      final buildah = caps('buildah', const ['bud']);
      expect(buildah, contains(CommandCapability.executePrograms));
      expect(caps('k9s', const []), contains(CommandCapability.readFilesystem));
    });

    test('editors and doc viewers', () {
      expect(
        caps('code', const ['.']),
        containsAll(const [
          CommandCapability.readFilesystem,
          CommandCapability.writeFilesystem,
        ]),
      );
      expect(
        caps('man', const ['ls']),
        contains(CommandCapability.readFilesystem),
      );
    });

    test('database drop is highRisk; new clients reach network', () {
      expect(kb.analyze('dropdb', const ['mydb']).risk, SecurityLevel.highRisk);
      expect(caps('pgcli', const []), contains(CommandCapability.networkRead));
    });

    test('crypto/secrets and VPN tools', () {
      expect(
        caps('age', const ['-e', 'f']),
        containsAll(const [
          CommandCapability.readFilesystem,
          CommandCapability.writeFilesystem,
        ]),
      );
      expect(
        kb.analyze('security', const ['find-generic-password']).risk,
        SecurityLevel.highRisk,
      );
      expect(
        caps('tailscale', const ['up']),
        containsAll(const [
          CommandCapability.networkWrite,
          CommandCapability.systemConfiguration,
        ]),
      );
    });

    test('archive/compression additions read + write', () {
      for (final c in const ['rar', 'unrar', 'lzip', 'lzop']) {
        expect(
          caps(c, const []),
          containsAll(const [
            CommandCapability.readFilesystem,
            CommandCapability.writeFilesystem,
          ]),
          reason: c,
        );
      }
    });
  });

  group('Phase 2 refinement depth', () {
    test('kubectl verbs split read/write/delete/exec', () {
      final get = caps('kubectl', const ['get', 'pods']);
      expect(get, contains(CommandCapability.networkRead));
      expect(get, isNot(contains(CommandCapability.networkWrite)));
      expect(
        caps('kubectl', const ['apply', '-f', 'x']),
        contains(CommandCapability.networkWrite),
      );
      final del = kb.analyze('kubectl', const ['delete', 'pod', 'x']);
      expect(del.capabilities, contains(CommandCapability.deleteFilesystem));
      expect(del.risk, SecurityLevel.highRisk);
      expect(
        caps('kubectl', const ['exec', 'pod', '--', 'sh']),
        contains(CommandCapability.executePrograms),
      );
    });

    test('terraform plan stays low; apply/destroy escalate', () {
      final plan = kb.analyze('terraform', const ['plan']);
      expect(plan.capabilities, contains(CommandCapability.networkRead));
      expect(
        plan.capabilities,
        isNot(contains(CommandCapability.networkWrite)),
      );
      expect(plan.risk, SecurityLevel.safe);
      expect(
        kb.analyze('terraform', const ['apply']).risk,
        SecurityLevel.mediumRisk,
      );
      expect(
        kb.analyze('terraform', const ['destroy']).risk,
        SecurityLevel.highRisk,
      );
      expect(
        kb.analyze('terraform', const ['apply', '-auto-approve']).risk,
        SecurityLevel.highRisk,
      );
    });

    test('systemctl status is read-only; mutations touch system config', () {
      final status = caps('systemctl', const ['status', 'nginx']);
      expect(status, contains(CommandCapability.readFilesystem));
      expect(status, isNot(contains(CommandCapability.systemConfiguration)));
      expect(
        caps('systemctl', const ['restart', 'nginx']),
        contains(CommandCapability.systemConfiguration),
      );
      expect(
        kb.analyze('systemctl', const ['reboot']).risk,
        SecurityLevel.highRisk,
      );
    });

    test('npm run executes; install still reaches the network', () {
      expect(
        caps('npm', const ['run', 'build']),
        contains(CommandCapability.executePrograms),
      );
      expect(
        caps('npm', const ['install']),
        contains(CommandCapability.networkRead),
      );
    });

    test('docker rm deletes; aws delete-token raises risk', () {
      expect(
        caps('docker', const ['rm', 'c']),
        contains(CommandCapability.deleteFilesystem),
      );
      expect(
        kb.analyze('aws', const ['s3', 'rm', 's3://b/k']).risk,
        SecurityLevel.mediumRisk,
      );
      expect(kb.analyze('aws', const ['s3', 'ls']).risk, SecurityLevel.safe);
    });

    test('vault read vs write; ansible-playbook --become escalates', () {
      final read = caps('vault', const ['read', 'secret/x']);
      expect(read, contains(CommandCapability.networkRead));
      expect(read, isNot(contains(CommandCapability.networkWrite)));
      expect(
        caps('vault', const ['write', 'secret/x', 'a=b']),
        contains(CommandCapability.networkWrite),
      );
      expect(
        caps('ansible-playbook', const ['site.yml', '--become']),
        contains(CommandCapability.privilegeEscalation),
      );
    });

    test('kill targeting init / all is highRisk; normal kill is safe', () {
      expect(kb.analyze('kill', const ['1']).risk, SecurityLevel.highRisk);
      expect(
        kb.analyze('kill', const ['-9', '1']).risk,
        SecurityLevel.highRisk,
      );
      expect(
        kb.analyze('kill', const ['-9', '-1']).risk,
        SecurityLevel.highRisk,
      );
      // Normal kill (incl. SIGHUP to a real PID) must NOT be flagged.
      expect(kb.analyze('kill', const ['-9', '1234']).risk, SecurityLevel.safe);
      expect(kb.analyze('kill', const ['-1', '1234']).risk, SecurityLevel.safe);
    });

    test('pkill/killall broad selectors are highRisk; a name is safe', () {
      expect(kb.analyze('pkill', const ['.']).risk, SecurityLevel.highRisk);
      expect(
        kb.analyze('pkill', const ['-u', 'root']).risk,
        SecurityLevel.highRisk,
      );
      expect(
        kb.analyze('killall', const ['-9', 'nginx']).risk,
        SecurityLevel.safe,
      );
    });

    test('recursive chmod/chown on a system root is highRisk', () {
      expect(
        kb.analyze('chmod', const ['-R', '777', '/']).risk,
        SecurityLevel.highRisk,
      );
      expect(
        kb.analyze('chown', const ['-R', 'me', '/etc']).risk,
        SecurityLevel.highRisk,
      );
      // Non-recursive, or a local path, stays safe.
      expect(kb.analyze('chmod', const ['644', 'f']).risk, SecurityLevel.safe);
      expect(
        kb.analyze('chmod', const ['-R', '755', './build']).risk,
        SecurityLevel.safe,
      );
    });

    test('"command -v foo" looks up, does not inherit foo\'s caps', () {
      // `command -v rm` resolves rm without running it → read-only, NOT delete.
      final lookup = kb.analyze('command', const ['-v', 'rm']);
      expect(lookup.capabilities, contains(CommandCapability.readFilesystem));
      expect(
        lookup.capabilities,
        isNot(contains(CommandCapability.deleteFilesystem)),
      );
      // `command -v mkfs` must not inherit mkfs's critical risk.
      expect(
        kb.analyze('command', const ['-v', 'mkfs']).risk,
        SecurityLevel.safe,
      );
      // But actually running a command through `command` still looks through.
      expect(
        kb.analyze('command', const ['rm', '-rf', 'x']).capabilities,
        contains(CommandCapability.deleteFilesystem),
      );
    });
  });
}
