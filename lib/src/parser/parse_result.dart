import 'package:meta/meta.dart' show immutable;

import '../ast/command_node.dart';
import '../syntax.dart';
import 'parse_diagnostic.dart';

/// The outcome of parsing a raw command string with a [CommandSyntax].
///
/// A result always carries the original [raw] input and the [syntax] used. The
/// [ast] is `null` only when the input was empty or could not be parsed into
/// any node; in all other cases a best-effort tree is provided alongside any
/// [diagnostics].
@immutable
final class ParseResult {
  /// Creates a parse result.
  const ParseResult({
    required this.raw,
    required this.syntax,
    required this.ast,
    this.diagnostics = const <ParseDiagnostic>[],
  });

  /// The original, unmodified input string.
  final String raw;

  /// The syntax used to parse [raw].
  final CommandSyntax syntax;

  /// The parsed AST, or `null` if nothing could be parsed.
  final CommandNode? ast;

  /// Diagnostics gathered during parsing, in source order.
  final List<ParseDiagnostic> diagnostics;

  /// Whether any [diagnostics] has [DiagnosticSeverity.error] severity.
  bool get hasErrors =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.error);

  /// Whether parsing produced a usable AST.
  bool get isSuccess => ast != null;

  /// Every [CommandNode] in [ast], depth-first, or empty if [ast] is `null`.
  Iterable<CommandNode> get allNodes => ast?.walk() ?? const <CommandNode>[];

  /// Every [CommandInvocation] contained in [ast], depth-first.
  Iterable<CommandInvocation> get invocations =>
      allNodes.whereType<CommandInvocation>();

  @override
  String toString() =>
      'ParseResult(syntax: ${syntax.name}, ast: $ast, '
      'diagnostics: $diagnostics)';
}
