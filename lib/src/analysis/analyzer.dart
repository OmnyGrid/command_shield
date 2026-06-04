import '../capabilities/capability.dart';
import '../capabilities/capability_detector.dart';
import '../classification/effect.dart';
import '../classification/effect_classifier.dart';
import '../normalization/normalizer.dart';
import '../parser/parse_result.dart';
import '../security/security_analyzer.dart';
import '../security/security_detector.dart';
import 'command_analysis.dart';

/// Orchestrates the post-parse stages of the pipeline:
/// normalization → capability detection → effect classification → security
/// analysis, producing a single [CommandAnalysis].
///
/// All collaborators are injectable so behaviour can be customised or extended.
final class Analyzer {
  /// Creates an analyzer.
  Analyzer({
    Normalizer? normalizer,
    CapabilityDetector? capabilityDetector,
    EffectClassifier? effectClassifier,
    SecurityAnalyzer? securityAnalyzer,
  }) : _normalizer = normalizer ?? Normalizer.standard(),
       _capabilityDetector =
           capabilityDetector ??
           CapabilityDetector(normalizer: normalizer ?? Normalizer.standard()),
       _effectClassifier = effectClassifier ?? const EffectClassifier(),
       _securityAnalyzer = securityAnalyzer ?? SecurityAnalyzer();

  final Normalizer _normalizer;
  final CapabilityDetector _capabilityDetector;
  final EffectClassifier _effectClassifier;
  final SecurityAnalyzer _securityAnalyzer;

  /// Analyses an already-parsed [parseResult].
  CommandAnalysis analyze(ParseResult parseResult) {
    final ast = parseResult.ast;

    final normalizedExecutables = parseResult.invocations
        .where((inv) => inv.executable.isNotEmpty)
        .map((inv) => _normalizer.normalize(inv.executable))
        .toList(growable: false);

    final capabilities = ast == null
        ? <CommandCapability>{}
        : _capabilityDetector.detect(ast);

    final effects = ast == null
        ? <CommandEffect>{}
        : _effectClassifier.classify(capabilities);

    final report = _securityAnalyzer.analyze(
      SecurityContext(
        raw: parseResult.raw,
        syntax: parseResult.syntax,
        ast: ast,
        normalizer: _normalizer,
      ),
    );

    return CommandAnalysis(
      raw: parseResult.raw,
      syntax: parseResult.syntax,
      ast: ast,
      diagnostics: parseResult.diagnostics,
      normalizedExecutables: normalizedExecutables,
      capabilities: Set<CommandCapability>.unmodifiable(capabilities),
      effects: Set<CommandEffect>.unmodifiable(effects),
      securityLevel: report.level,
      findings: report.findings,
    );
  }
}
