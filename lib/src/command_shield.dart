import 'analysis/analyzer.dart';
import 'analysis/command_analysis.dart';
import 'normalization/normalizer.dart';
import 'parser/parse_result.dart';
import 'parser/parser_factory.dart';
import 'policies/command_policy.dart';
import 'policies/default_policy.dart';
import 'syntax.dart';
import 'validation/command_result.dart';

/// The high-level entry point of the package.
///
/// `CommandShield` wires the full pipeline together — parse → normalize →
/// detect capabilities → classify effects → analyse security → apply policy —
/// and exposes three deterministic, non-executing operations:
///
/// * [parse] — produce the typed AST and parse diagnostics.
/// * [analyze] — produce a full [CommandAnalysis].
/// * [validate] — produce a policy [CommandResult] (ALLOW / REVIEW / DENY).
///
/// ```dart
/// final shield = CommandShield();
/// final result = shield.validate('rm -rf /', syntax: CommandSyntax.bash);
/// print(result.decision); // CommandDecision.deny
/// ```
///
/// > **Security note.** This package *analyses* commands; it never runs them.
/// > Validation reduces risk but is **not** a substitute for sandboxing,
/// > containers, least privilege or process isolation.
final class CommandShield {
  /// Creates a shield.
  ///
  /// * [defaultSyntax] is used when a per-call `syntax` is not given.
  /// * [normalizer] customises executable normalization.
  /// * [policy] overrides the built-in default policy used by [validate].
  /// * [analyzer] overrides the analysis orchestrator (advanced use).
  CommandShield({
    this.defaultSyntax = CommandSyntax.generic,
    Normalizer? normalizer,
    CommandPolicy? policy,
    Analyzer? analyzer,
  }) : _policy = policy ?? buildDefaultPolicy(),
       _analyzer =
           analyzer ??
           Analyzer(normalizer: normalizer ?? Normalizer.standard());

  /// The syntax used when none is supplied to [parse], [analyze] or [validate].
  final CommandSyntax defaultSyntax;

  final Analyzer _analyzer;
  final CommandPolicy _policy;

  /// The policy applied by [validate].
  CommandPolicy get policy => _policy;

  /// Parses [command] into a [ParseResult]. Never throws.
  ParseResult parse(String command, {CommandSyntax? syntax}) =>
      ParserFactory.forSyntax(syntax ?? defaultSyntax).parse(command);

  /// Parses and fully analyses [command], returning a [CommandAnalysis]. Never
  /// throws.
  CommandAnalysis analyze(String command, {CommandSyntax? syntax}) =>
      _analyzer.analyze(parse(command, syntax: syntax));

  /// Parses, analyses and validates [command] against the configured [policy],
  /// returning a final ALLOW / REVIEW / DENY [CommandResult]. Never throws.
  CommandResult validate(String command, {CommandSyntax? syntax}) =>
      validateAnalysis(analyze(command, syntax: syntax));

  /// Validates an existing [analysis] against the configured [policy]. Useful
  /// when the analysis has already been computed.
  CommandResult validateAnalysis(CommandAnalysis analysis) =>
      _policy.evaluate(analysis);
}
