import 'package:meta/meta.dart' show immutable;

import '../ast/command_node.dart';
import '../capabilities/capability.dart';
import '../capabilities/command_knowledge_base.dart';
import '../classification/effect.dart';
import '../parser/parse_diagnostic.dart';
import '../security/security_finding.dart';
import '../security/security_level.dart';
import '../syntax.dart';

/// The complete, immutable result of analysing a command.
///
/// It bundles the parsed [ast], detected [capabilities] and [effects], the
/// aggregated [securityLevel] and [findings], and a set of convenience boolean
/// summaries. The booleans are **computed** from [capabilities] so they are
/// always consistent with one another.
@immutable
final class CommandAnalysis {
  /// Creates a command analysis.
  const CommandAnalysis({
    required this.raw,
    required this.syntax,
    required this.ast,
    required this.diagnostics,
    required this.normalizedExecutables,
    required this.capabilities,
    required this.effects,
    required this.securityLevel,
    required this.findings,
    this.knowledgeRisk = SecurityLevel.safe,
  });

  /// The original command string.
  final String raw;

  /// The syntax the command was parsed with.
  final CommandSyntax syntax;

  /// The parsed AST, or `null` if nothing could be parsed.
  final CommandNode? ast;

  /// Diagnostics produced during parsing.
  final List<ParseDiagnostic> diagnostics;

  /// The normalized executable names of every invocation, in source order.
  final List<String> normalizedExecutables;

  /// The capabilities the command may exercise.
  final Set<CommandCapability> capabilities;

  /// The high-level effects of the command.
  final Set<CommandEffect> effects;

  /// The overall security severity.
  final SecurityLevel securityLevel;

  /// The highest risk hint contributed by the command knowledge base across all
  /// invocations (for example, a force push). This is advisory metadata derived
  /// from the [CommandKnowledgeBase] and does **not** affect [securityLevel]
  /// unless a `KnowledgeRiskDetector` is explicitly enabled.
  final SecurityLevel knowledgeRisk;

  /// The aggregated security findings, sorted by descending severity.
  final List<SecurityFinding> findings;

  /// Whether the command neither mutates state, executes code, accesses the
  /// network, nor escalates privileges. Reading the filesystem, the
  /// environment, or process information is permitted.
  bool get isReadOnly =>
      !canModifySystem &&
      !canDeleteData &&
      !canExecuteCode &&
      !canAccessNetwork &&
      !canEscalatePrivileges;

  /// Whether the command can modify files or system/security configuration.
  bool get canModifySystem =>
      capabilities.contains(CommandCapability.writeFilesystem) ||
      capabilities.contains(CommandCapability.systemConfiguration);

  /// Whether the command can delete data from the filesystem.
  bool get canDeleteData =>
      capabilities.contains(CommandCapability.deleteFilesystem);

  /// Whether the command can read from or write to the network.
  bool get canAccessNetwork =>
      capabilities.contains(CommandCapability.networkRead) ||
      capabilities.contains(CommandCapability.networkWrite);

  /// Whether the command can execute other programs or interpret code.
  bool get canExecuteCode =>
      capabilities.contains(CommandCapability.executePrograms);

  /// Whether the command can escalate privileges.
  bool get canEscalatePrivileges =>
      capabilities.contains(CommandCapability.privilegeEscalation);

  /// Whether any parse diagnostic has [DiagnosticSeverity.error] severity.
  bool get hasParseErrors =>
      diagnostics.any((d) => d.severity == DiagnosticSeverity.error);

  /// Every [CommandInvocation] in [ast], depth-first.
  Iterable<CommandInvocation> get invocations =>
      ast?.walk().whereType<CommandInvocation>() ?? const <CommandInvocation>[];

  @override
  String toString() =>
      'CommandAnalysis(level: ${securityLevel.name}, '
      'capabilities: $capabilities, effects: $effects, '
      'findings: ${findings.length})';
}
