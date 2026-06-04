import 'package:command_shield/command_shield.dart';
import 'package:test/test.dart';

void main() {
  const classifier = EffectClassifier();

  group('EffectClassifier', () {
    test('readOnly when only reading', () {
      expect(classifier.classify({CommandCapability.readFilesystem}), {
        CommandEffect.readOnly,
      });
    });

    test('modifyFiles', () {
      expect(
        classifier.classify({CommandCapability.writeFilesystem}),
        contains(CommandEffect.modifyFiles),
      );
    });

    test('deleteFiles', () {
      expect(
        classifier.classify({CommandCapability.deleteFilesystem}),
        contains(CommandEffect.deleteFiles),
      );
    });

    test('executeCode', () {
      expect(
        classifier.classify({CommandCapability.executePrograms}),
        contains(CommandEffect.executeCode),
      );
    });

    test('networkAccess from read', () {
      expect(
        classifier.classify({CommandCapability.networkRead}),
        contains(CommandEffect.networkAccess),
      );
    });

    test('networkAccess from write', () {
      expect(
        classifier.classify({CommandCapability.networkWrite}),
        contains(CommandEffect.networkAccess),
      );
    });

    test('systemModification', () {
      expect(
        classifier.classify({CommandCapability.systemConfiguration}),
        contains(CommandEffect.systemModification),
      );
    });

    test('privilegeEscalation', () {
      expect(
        classifier.classify({CommandCapability.privilegeEscalation}),
        contains(CommandEffect.privilegeEscalation),
      );
    });

    test('readOnly is suppressed when a side effect is present', () {
      final effects = classifier.classify({
        CommandCapability.readFilesystem,
        CommandCapability.deleteFilesystem,
      });
      expect(effects, contains(CommandEffect.deleteFiles));
      expect(effects, isNot(contains(CommandEffect.readOnly)));
    });

    test('environment-only access counts as read-only', () {
      expect(
        classifier.classify({CommandCapability.environmentAccess}),
        contains(CommandEffect.readOnly),
      );
    });

    test('empty capabilities produce no effects', () {
      expect(classifier.classify({}), isEmpty);
    });
  });
}
