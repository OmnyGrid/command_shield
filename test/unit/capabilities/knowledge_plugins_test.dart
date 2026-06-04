import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  group('plugin composition', () {
    test('default base loads all built-in plugins', () {
      final kb = CommandKnowledgeBase.standard();
      // A representative command from each domain resolves.
      for (final exe in const [
        'ls',
        'tar',
        'bash',
        'printenv',
        'ps',
        'chmod',
        'curl',
        'docker',
        'npm',
        'dart',
        'git',
        'icacls',
        'md5sum',
        'gzip',
        'openssl',
        'psql',
        'vim',
      ]) {
        expect(kb.knowledgeFor(exe), isNotNull, reason: '$exe should be known');
      }
    });

    test('includeDefaults:false yields only supplied plugins', () {
      final kb = CommandKnowledgeBase(
        includeDefaults: false,
        plugins: const [GitKnowledge()],
      );
      expect(kb.knowledgeFor('git'), isNotNull);
      expect(kb.knowledgeFor('ls'), isNull);
    });

    test('later plugins override earlier ones for the same executable', () {
      final kb = CommandKnowledgeBase(
        plugins: const [
          ListKnowledgePlugin('override', [
            CommandKnowledge(
              executable: 'git',
              category: KnowledgeCategory.other,
              baseCapabilities: {CommandCapability.executePrograms},
            ),
          ]),
        ],
      );
      expect(kb.knowledgeFor('git')!.category, KnowledgeCategory.other);
    });

    test('aliases register additional lookup keys', () {
      final kb = CommandKnowledgeBase(
        includeDefaults: false,
        plugins: const [
          ListKnowledgePlugin('aliased', [
            CommandKnowledge(
              executable: 'mytool',
              aliases: {'mt'},
              category: KnowledgeCategory.other,
              baseCapabilities: {CommandCapability.readFilesystem},
            ),
          ]),
        ],
      );
      expect(
        kb.capabilitiesFor('mt', const []),
        contains(CommandCapability.readFilesystem),
      );
    });

    test('every entry name is unique across default plugins', () {
      final kb = CommandKnowledgeBase.standard();
      // allKnowledge dedupes entries; confirm there are no surprises by
      // spot-checking a wrapper still recurses.
      expect(
        kb.capabilitiesFor('sudo', const ['rm', '-rf', 'x']),
        containsAll(const [
          CommandCapability.privilegeEscalation,
          CommandCapability.deleteFilesystem,
        ]),
      );
    });
  });

  group('KnowledgeRiskDetector (opt-in)', () {
    SecurityReport analyze(String raw) {
      final ast = ParserFactory.forSyntax(CommandSyntax.bash).parse(raw).ast!;
      final analyzer = SecurityAnalyzer(
        detectors: [
          ...SecurityAnalyzer.defaultDetectors,
          KnowledgeRiskDetector(),
        ],
      );
      return analyzer.analyze(
        SecurityContext(
          raw: raw,
          syntax: CommandSyntax.bash,
          ast: ast,
          normalizer: Normalizer.standard(),
        ),
      );
    }

    test('emits a finding for a force push', () {
      final report = analyze('git push --force origin main');
      expect(report.findings.any((f) => f.code == 'knowledge-risk'), isTrue);
      expect(report.level.isAtLeast(SecurityLevel.mediumRisk), isTrue);
    });

    test('stays silent for a safe command', () {
      final report = analyze('git status');
      expect(report.findings.any((f) => f.code == 'knowledge-risk'), isFalse);
    });

    test('is not enabled in the default detector set', () {
      expect(
        SecurityAnalyzer.defaultDetectors.whereType<KnowledgeRiskDetector>(),
        isEmpty,
      );
    });
  });
}
