import 'package:meta/meta.dart' show immutable;

import 'default_rules.dart';

/// A single, named rule that maps a raw executable name to a canonical form.
///
/// Rules are pure functions of their input and must be deterministic. Returning
/// the input unchanged means the rule does not apply.
@immutable
final class NormalizationRule {
  /// Creates a normalization rule.
  const NormalizationRule({
    required this.name,
    required this.description,
    required this.apply,
  });

  /// A short identifier for the rule (used in explanations/tests).
  final String name;

  /// A human-readable description of what the rule does.
  final String description;

  /// The transformation. Receives the current executable string and returns
  /// the transformed string (or the same string if it does not apply).
  final String Function(String executable) apply;
}

/// Normalizes executable names to a canonical form so downstream stages can
/// reason about commands regardless of how they were written.
///
/// Examples (with the default rules):
///
/// * `/bin/rm` → `rm`
/// * `powershell.exe` → `powershell`
/// * `python3` → `python`
///
/// The rule set is fully extensible: pass custom [rules], or derive a new
/// normalizer with [withRules].
@immutable
final class Normalizer {
  /// Creates a normalizer from an ordered list of [rules].
  ///
  /// Rules are applied in order; each rule sees the output of the previous one.
  const Normalizer(this.rules);

  /// Creates a normalizer using the built-in default rule set.
  factory Normalizer.standard() => Normalizer(defaultNormalizationRules);

  /// The ordered rules applied by [normalize].
  final List<NormalizationRule> rules;

  /// Returns a new normalizer whose rule list is this normalizer's rules with
  /// [extra] appended.
  Normalizer withRules(List<NormalizationRule> extra) =>
      Normalizer(<NormalizationRule>[...rules, ...extra]);

  /// Applies every rule, in order, to [executable] and returns the canonical
  /// form. Whitespace is trimmed first.
  String normalize(String executable) {
    var current = executable.trim();
    for (final rule in rules) {
      current = rule.apply(current);
    }
    return current;
  }
}
