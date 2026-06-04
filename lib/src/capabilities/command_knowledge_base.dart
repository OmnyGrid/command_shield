import '../security/security_level.dart';
import 'capability.dart';
import 'knowledge/command_knowledge.dart';
import 'knowledge/command_knowledge_plugin.dart';
import 'knowledge/command_knowledge_result.dart';
import 'knowledge/plugins/default_plugins.dart';

/// A plugin-composed knowledge base mapping commands (and their sub-commands and
/// arguments) to the [CommandCapability]s they exercise and a [SecurityLevel]
/// risk hint.
///
/// Knowledge is contributed by [CommandKnowledgePlugin]s — one per domain (git,
/// filesystem, package managers, …). Construct with the defaults, extend them
/// with extra plugins, or replace them entirely:
///
/// ```dart
/// // Defaults only.
/// final kb = CommandKnowledgeBase.standard();
///
/// // Defaults plus a custom plugin.
/// final kb = CommandKnowledgeBase(plugins: [MyToolKnowledge()]);
///
/// // Only my plugins, no built-ins.
/// final kb = CommandKnowledgeBase(plugins: [MyToolKnowledge()],
///                                 includeDefaults: false);
/// ```
///
/// The base is intentionally heuristic and conservative: when in doubt it errs
/// toward reporting a capability rather than omitting it.
final class CommandKnowledgeBase {
  /// Creates a knowledge base from [plugins].
  ///
  /// When [includeDefaults] is true (the default), [defaultKnowledgePlugins]
  /// are registered first and any [plugins] are layered on top, so a later
  /// plugin can override an executable defined by an earlier one.
  CommandKnowledgeBase({
    List<CommandKnowledgePlugin>? plugins,
    bool includeDefaults = true,
  }) : _table = _buildTable([
         if (includeDefaults) ...defaultKnowledgePlugins,
         ...?plugins,
       ]);

  /// Creates a knowledge base from the built-in plugins only.
  CommandKnowledgeBase.standard() : this();

  /// The (lower-cased) executable/alias → knowledge table.
  final Map<String, CommandKnowledge> _table;

  static Map<String, CommandKnowledge> _buildTable(
    List<CommandKnowledgePlugin> plugins,
  ) {
    final table = <String, CommandKnowledge>{};
    for (final plugin in plugins) {
      for (final entry in plugin.entries) {
        for (final name in entry.allNames) {
          table[name.toLowerCase()] = entry;
        }
      }
    }
    return table;
  }

  /// Every distinct knowledge entry in the base.
  Iterable<CommandKnowledge> get allKnowledge => _table.values.toSet();

  /// Returns the knowledge entry for [executable], or `null` if unknown.
  CommandKnowledge? knowledgeFor(String executable) =>
      _table[executable.toLowerCase()];

  /// Returns the set of capabilities for an invocation of [executable] with
  /// [arguments].
  ///
  /// A convenience wrapper over [analyze] for callers that only need the
  /// capabilities (such as `CapabilityDetector`).
  Set<CommandCapability> capabilitiesFor(
    String executable,
    List<String> arguments,
  ) => analyze(executable, arguments).capabilities;

  /// Performs a full analysis of an invocation of [executable] with
  /// [arguments], returning the capabilities, an aggregated risk hint, the
  /// matched knowledge entry and explanatory notes.
  CommandKnowledgeResult analyze(String executable, List<String> arguments) {
    final match = KnowledgeMatch();
    final root = _collect(executable.toLowerCase(), arguments, match, depth: 0);
    return CommandKnowledgeResult(
      capabilities: match.capabilities,
      risk: match.risk,
      knowledge: root,
      notes: match.notes,
    );
  }

  /// Accumulates the knowledge for [exe] with [args] into [match] and returns
  /// the matched entry for [exe] (the root invocation's entry), if any.
  CommandKnowledge? _collect(
    String exe,
    List<String> args,
    KnowledgeMatch match, {
    required int depth,
  }) {
    final entry = _table[exe];
    if (entry != null) {
      match.addAll(entry.baseCapabilities);
      match.raiseRisk(entry.baseRisk);
      _refine(entry, args, match);
    }

    // Any environment-variable token implies environment access.
    if (args.any(_looksLikeEnvReference)) {
      match.add(CommandCapability.environmentAccess);
    }

    // Recurse into wrapped commands (sudo/env/xargs/...), bounded to avoid
    // pathological inputs.
    if (entry?.wrapper != null && depth < 4) {
      final wrapped = _wrappedCommand(entry!.wrapper!, args);
      if (wrapped != null) {
        _collect(
          wrapped.executable,
          wrapped.arguments,
          match,
          depth: depth + 1,
        );
      }
    }
    return depth == 0 ? entry : null;
  }

  void _refine(
    CommandKnowledge entry,
    List<String> args,
    KnowledgeMatch match,
  ) {
    final sub = _firstNonFlag(args)?.toLowerCase();
    if (sub != null) {
      for (final rule in entry.subcommands) {
        if (rule.names.contains(sub)) {
          match.addAll(rule.capabilities);
          match.raiseRisk(rule.risk);
          match.note(rule.description);
        }
      }
    }
    for (final rule in entry.argumentRules) {
      if (rule.match.matches(args)) {
        match.addAll(rule.capabilities);
        match.raiseRisk(rule.risk);
        match.note(rule.description);
      }
    }
    entry.refine?.call(args, match);
  }

  _Wrapped? _wrappedCommand(WrapperSpec spec, List<String> args) {
    var i = 0;
    while (i < args.length) {
      final a = args[i];
      if (spec.skipLeadingFlags && a.startsWith('-')) {
        i++;
        continue;
      }
      if (spec.skipAssignments && a.contains('=')) {
        i++;
        continue;
      }
      break;
    }
    if (i >= args.length) return null;
    return _Wrapped(args[i].toLowerCase(), args.sublist(i + 1));
  }

  static String? _firstNonFlag(List<String> args) {
    for (final a in args) {
      if (!a.startsWith('-')) return a;
    }
    return null;
  }

  static bool _looksLikeEnvReference(String token) =>
      token.contains(RegExp(r'\$[A-Za-z_]')) ||
      token.contains(RegExp(r'\$\{[A-Za-z_]')) ||
      token.contains(RegExp(r'\$env:')) ||
      token.contains(RegExp(r'%[A-Za-z_][A-Za-z0-9_]*%'));
}

class _Wrapped {
  _Wrapped(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}
