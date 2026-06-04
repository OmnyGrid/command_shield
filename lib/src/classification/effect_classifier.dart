import '../capabilities/capability.dart';
import 'effect.dart';

/// Maps a set of [CommandCapability]s to a set of [CommandEffect]s.
///
/// The mapping is deterministic. [CommandEffect.readOnly] is reported only when
/// no mutating, executing, network or privilege capability is present.
final class EffectClassifier {
  /// Creates an effect classifier.
  const EffectClassifier();

  /// Classifies [capabilities] into the corresponding effects.
  Set<CommandEffect> classify(Set<CommandCapability> capabilities) {
    final effects = <CommandEffect>{};

    if (capabilities.contains(CommandCapability.writeFilesystem)) {
      effects.add(CommandEffect.modifyFiles);
    }
    if (capabilities.contains(CommandCapability.deleteFilesystem)) {
      effects.add(CommandEffect.deleteFiles);
    }
    if (capabilities.contains(CommandCapability.executePrograms)) {
      effects.add(CommandEffect.executeCode);
    }
    if (capabilities.contains(CommandCapability.networkRead) ||
        capabilities.contains(CommandCapability.networkWrite)) {
      effects.add(CommandEffect.networkAccess);
    }
    if (capabilities.contains(CommandCapability.systemConfiguration)) {
      effects.add(CommandEffect.systemModification);
    }
    if (capabilities.contains(CommandCapability.privilegeEscalation)) {
      effects.add(CommandEffect.privilegeEscalation);
    }

    final hasSideEffect = effects.isNotEmpty;
    final readsSomething =
        capabilities.contains(CommandCapability.readFilesystem) ||
        capabilities.contains(CommandCapability.environmentAccess) ||
        capabilities.contains(CommandCapability.processManagement);

    if (!hasSideEffect && readsSomething) {
      effects.add(CommandEffect.readOnly);
    }
    // A completely unknown command produces no capabilities; treat it as
    // read-only-equivalent only if nothing else applies, leaving the set
    // empty so callers/policies can flag the unknown rather than assume safe.
    return effects;
  }
}
