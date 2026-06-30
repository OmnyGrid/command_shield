import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  final detector = CapabilityDetector();
  const parser = BashParser();

  Set<CommandCapability> caps(String raw) =>
      detector.detect(parser.parse(raw).ast!);

  group('CapabilityDetector', () {
    test('readFilesystem', () {
      expect(caps('cat file.txt'), contains(CommandCapability.readFilesystem));
      expect(caps('git status'), contains(CommandCapability.readFilesystem));
    });

    test('writeFilesystem', () {
      expect(caps('touch a'), contains(CommandCapability.writeFilesystem));
      expect(caps('mkdir d'), contains(CommandCapability.writeFilesystem));
    });

    test('deleteFilesystem', () {
      expect(
        caps('rm -rf build'),
        contains(CommandCapability.deleteFilesystem),
      );
      expect(caps('rmdir d'), contains(CommandCapability.deleteFilesystem));
    });

    test('executePrograms', () {
      expect(caps('dart test'), contains(CommandCapability.executePrograms));
      expect(
        caps('python app.py'),
        contains(CommandCapability.executePrograms),
      );
    });

    test('networkRead', () {
      expect(caps('curl http://x'), contains(CommandCapability.networkRead));
      expect(caps('git pull'), contains(CommandCapability.networkRead));
      expect(caps('git clone repo'), contains(CommandCapability.networkRead));
    });

    test('networkWrite', () {
      expect(
        caps('git push origin main'),
        contains(CommandCapability.networkWrite),
      );
      expect(
        caps('curl -X POST http://x'),
        contains(CommandCapability.networkWrite),
      );
    });

    test('processManagement', () {
      expect(caps('kill 123'), contains(CommandCapability.processManagement));
      expect(caps('ps aux'), contains(CommandCapability.processManagement));
    });

    test('privilegeEscalation', () {
      expect(
        caps('sudo apt-get update'),
        contains(CommandCapability.privilegeEscalation),
      );
    });

    test('systemConfiguration', () {
      expect(
        caps('chmod 777 file'),
        contains(CommandCapability.systemConfiguration),
      );
      expect(
        caps('chown root file'),
        contains(CommandCapability.systemConfiguration),
      );
    });

    test('environmentAccess from env var reference', () {
      expect(
        caps(r'echo $HOME'),
        contains(CommandCapability.environmentAccess),
      );
      expect(caps('printenv'), contains(CommandCapability.environmentAccess));
    });

    test('multiple capabilities for one command', () {
      final c = caps('git push origin main');
      expect(c, contains(CommandCapability.networkWrite));
    });

    test('wrapper commands attribute wrapped capabilities', () {
      final c = caps('sudo rm -rf /tmp/x');
      expect(c, contains(CommandCapability.privilegeEscalation));
      expect(c, contains(CommandCapability.deleteFilesystem));
    });

    test('redirection implies write', () {
      expect(
        caps('echo hi > out.txt'),
        contains(CommandCapability.writeFilesystem),
      );
    });

    test('input redirection implies read', () {
      expect(
        caps('sort < data.txt'),
        contains(CommandCapability.readFilesystem),
      );
    });

    test('stream merge 2>&1 implies no filesystem write', () {
      // `ls` reads the filesystem; the merge itself must add nothing.
      final c = caps('ls 2>&1');
      expect(c, isNot(contains(CommandCapability.writeFilesystem)));
    });

    test('discard to /dev/null implies no filesystem write', () {
      expect(
        caps('echo hi > /dev/null'),
        isNot(contains(CommandCapability.writeFilesystem)),
      );
      expect(
        caps('cmd 2> /dev/null'),
        isNot(contains(CommandCapability.writeFilesystem)),
      );
      expect(
        caps('cmd &> /dev/null'),
        isNot(contains(CommandCapability.writeFilesystem)),
      );
    });

    test('combined redirect to a real file still implies write', () {
      expect(
        caps('cmd &> out.log'),
        contains(CommandCapability.writeFilesystem),
      );
    });

    test('command substitution implies execute', () {
      expect(
        caps(r'echo $(whoami)'),
        contains(CommandCapability.executePrograms),
      );
    });

    test('mv implies write and delete', () {
      final c = caps('mv a b');
      expect(c, contains(CommandCapability.writeFilesystem));
      expect(c, contains(CommandCapability.deleteFilesystem));
    });

    test('npm install implies network + write', () {
      final c = caps('npm install');
      expect(c, contains(CommandCapability.networkRead));
      expect(c, contains(CommandCapability.writeFilesystem));
    });

    test('unknown command yields no capabilities', () {
      expect(caps('frobnicate xyz'), isEmpty);
    });

    test('knowledge base is extensible', () {
      final kb = CommandKnowledgeBase(
        plugins: const [
          ListKnowledgePlugin('custom', [
            CommandKnowledge(
              executable: 'frobnicate',
              category: KnowledgeCategory.other,
              baseCapabilities: {CommandCapability.networkWrite},
            ),
          ]),
        ],
      );
      final custom = CapabilityDetector(knowledgeBase: kb);
      expect(
        custom.detect(parser.parse('frobnicate x').ast!),
        contains(CommandCapability.networkWrite),
      );
    });
  });
}
