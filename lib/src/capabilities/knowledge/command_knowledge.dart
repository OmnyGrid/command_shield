import 'package:meta/meta.dart' show immutable;

import '../../security/security_level.dart';
import '../capability.dart';

/// The broad domain a command belongs to.
///
/// Categories are purely descriptive metadata; they do not affect capability
/// detection. They make the knowledge base browsable and let tooling group or
/// filter commands (for example, "show every package manager").
enum KnowledgeCategory {
  /// Version-control tools (`git`, `hg`, `svn`).
  versionControl,

  /// Filesystem manipulation (`ls`, `cp`, `rm`, …).
  filesystem,

  /// Archive and bundling tools (`tar`, `7z`, `cpio`, …).
  archive,

  /// Single-stream compressors and zip tools (`gzip`, `zip`, `xz`, …).
  compression,

  /// Checksum and digest tools (`md5sum`, `sha256sum`, `cksum`, …).
  hash,

  /// Encryption, signing and encoding tools (`openssl`, `gpg`, `base64`, …).
  crypto,

  /// Database clients and dump/restore tools (`psql`, `mysql`, `sqlite3`, …).
  database,

  /// Interactive text editors (`vim`, `nano`, `emacs`, …).
  editor,

  /// Software package managers (`npm`, `pip`, `apt`, `brew`, …).
  packageManager,

  /// Container and orchestration tools (`docker`, `podman`, `kubectl`).
  container,

  /// Infrastructure-as-code and configuration-management tools (`terraform`,
  /// `ansible`, `pulumi`, `vault`, …).
  infrastructure,

  /// Network clients and utilities (`curl`, `ssh`, `ping`, cloud CLIs).
  network,

  /// Shells and command wrappers (`bash`, `sudo`, `env`, …).
  shell,

  /// Language interpreters and build tools (`python`, `dart`, `make`, …).
  interpreter,

  /// Process inspection and control (`ps`, `kill`, `top`, …).
  process,

  /// System and security configuration (`chmod`, `systemctl`, `reg`, …).
  system,

  /// Environment-variable utilities (`env`, `printenv`, `export`).
  environment,

  /// Anything that does not fit a more specific category.
  other,
}

/// The operating systems on which a command is commonly available.
enum CommandPlatform {
  /// Linux distributions.
  linux,

  /// Apple macOS.
  macos,

  /// Microsoft Windows.
  windows,

  /// Available across all major platforms.
  cross,
}

/// A mutable accumulator passed to declarative rules and [KnowledgeRefiner]
/// hooks while a command is being analysed.
///
/// Rules add capabilities, raise the risk level and append explanatory notes;
/// the registry collects the final state into a `CommandKnowledgeResult`.
final class KnowledgeMatch {
  /// The capabilities accumulated so far.
  final Set<CommandCapability> capabilities = <CommandCapability>{};

  /// Human-readable notes from the rules that matched.
  final List<String> notes = <String>[];

  SecurityLevel _risk = SecurityLevel.safe;

  /// The highest risk level observed so far.
  SecurityLevel get risk => _risk;

  /// Adds a single [capability].
  void add(CommandCapability capability) => capabilities.add(capability);

  /// Adds every capability in [caps].
  void addAll(Iterable<CommandCapability> caps) => capabilities.addAll(caps);

  /// Raises [risk] to at least [level] (never lowers it).
  void raiseRisk(SecurityLevel level) => _risk = _risk.max(level);

  /// Records an explanatory [note], ignoring blank or duplicate entries.
  void note(String? note) {
    if (note == null || note.isEmpty || notes.contains(note)) return;
    notes.add(note);
  }
}

/// A predicate over the argument tokens of an invocation, used by
/// [ArgumentRule] to decide whether the rule applies.
///
/// Subclasses cover the common cases declaratively; [ArgPredicate] is the
/// escape hatch for arbitrary logic.
@immutable
sealed class ArgumentMatch {
  /// Const base constructor.
  const ArgumentMatch();

  /// Whether this match applies to [args].
  bool matches(List<String> args);
}

/// Matches when any argument is exactly equal to one of [flags].
///
/// Use for long/short flags that take no value, e.g. `{'-i', '--in-place'}`.
final class ExactFlag extends ArgumentMatch {
  /// Creates an exact-flag match.
  const ExactFlag(this.flags);

  /// The flags to look for.
  final Set<String> flags;

  @override
  bool matches(List<String> args) => args.any(flags.contains);
}

/// Matches when any argument equals, or starts with, one of [prefixes].
///
/// Use for flags that may be glued to their value, e.g. `-i` matching both
/// `-i` and `-i.bak` (as `sed -i.bak`).
final class PrefixFlag extends ArgumentMatch {
  /// Creates a prefix-flag match.
  const PrefixFlag(this.prefixes);

  /// The flag prefixes to look for.
  final Set<String> prefixes;

  @override
  bool matches(List<String> args) =>
      args.any((a) => prefixes.any((p) => a == p || a.startsWith(p)));
}

/// Matches when any of [tokens] appears anywhere in the arguments.
///
/// Use for positional sub-flags such as `find … -delete` or `-exec`.
final class TokenPresent extends ArgumentMatch {
  /// Creates a token-present match.
  const TokenPresent(this.tokens);

  /// The tokens to look for.
  final Set<String> tokens;

  @override
  bool matches(List<String> args) => args.any(tokens.contains);
}

/// Matches when any argument matches [pattern].
final class ArgRegex extends ArgumentMatch {
  /// Creates a regex match.
  const ArgRegex(this.pattern);

  /// The pattern each argument is tested against.
  final RegExp pattern;

  @override
  bool matches(List<String> args) => args.any(pattern.hasMatch);
}

/// Matches according to an arbitrary [test] function — the escape hatch for
/// logic that the declarative matchers cannot express.
final class ArgPredicate extends ArgumentMatch {
  /// Creates a predicate match.
  const ArgPredicate(this.test);

  /// The predicate evaluated against the full argument list.
  final bool Function(List<String> args) test;

  @override
  bool matches(List<String> args) => test(args);
}

/// A rule that attributes [capabilities] (and an optional elevated [risk]) when
/// the first non-flag argument — the "sub-command" — is one of [names].
@immutable
final class SubcommandRule {
  /// Creates a sub-command rule.
  const SubcommandRule(
    this.names,
    this.capabilities, {
    this.risk = SecurityLevel.safe,
    this.description,
  });

  /// The sub-command names this rule applies to (lower-cased).
  final Set<String> names;

  /// The capabilities attributed when [names] matches.
  final Set<CommandCapability> capabilities;

  /// The risk level this sub-command implies.
  final SecurityLevel risk;

  /// An optional human-readable explanation.
  final String? description;
}

/// A rule that attributes [capabilities] (and an optional elevated [risk]) when
/// [match] applies to the invocation's arguments.
@immutable
final class ArgumentRule {
  /// Creates an argument rule.
  const ArgumentRule(
    this.match,
    this.capabilities, {
    this.risk = SecurityLevel.safe,
    this.description,
  });

  /// The condition under which this rule fires.
  final ArgumentMatch match;

  /// The capabilities attributed when [match] applies.
  final Set<CommandCapability> capabilities;

  /// The risk level this argument pattern implies.
  final SecurityLevel risk;

  /// An optional human-readable explanation.
  final String? description;
}

/// Describes how a wrapper command (such as `sudo` or `env`) locates the
/// command it ultimately executes within its own arguments.
@immutable
final class WrapperSpec {
  /// Creates a wrapper specification.
  const WrapperSpec({
    this.skipLeadingFlags = true,
    this.skipAssignments = false,
    this.lookupFlags = const <String>{},
  });

  /// Whether leading `-`-prefixed option tokens are skipped before the wrapped
  /// executable is found.
  final bool skipLeadingFlags;

  /// Whether leading `NAME=VALUE` assignment tokens are skipped (as with
  /// `env FOO=bar cmd`).
  final bool skipAssignments;

  /// Flags that turn the wrapper into a *lookup* rather than an execution, so
  /// the named command is resolved/printed but **not** run (e.g. `command -v
  /// foo` / `command -V foo`). When any of these is present the wrapped command
  /// is not analysed; the invocation is treated as a read-only lookup.
  final Set<String> lookupFlags;
}

/// An optional Dart hook for command logic that the declarative rules cannot
/// express. It receives the invocation [args] and mutates [match] directly.
typedef KnowledgeRefiner =
    void Function(List<String> args, KnowledgeMatch match);

/// All knowledge the base holds about a single command (executable).
///
/// Entries are pure data plus optional function hooks; a plugin is simply a
/// list of them. The registry consults [baseCapabilities], then the matching
/// [subcommands] and [argumentRules], then any [refine] hook, accumulating the
/// result into a `CommandKnowledgeResult`.
@immutable
final class CommandKnowledge {
  /// Creates a knowledge entry.
  const CommandKnowledge({
    required this.executable,
    required this.category,
    this.aliases = const <String>{},
    this.platforms = const <CommandPlatform>{CommandPlatform.cross},
    this.description,
    this.baseCapabilities = const <CommandCapability>{},
    this.baseRisk = SecurityLevel.safe,
    this.subcommands = const <SubcommandRule>[],
    this.argumentRules = const <ArgumentRule>[],
    this.wrapper,
    this.refine,
  });

  /// The canonical, lower-cased executable name (e.g. `git`).
  final String executable;

  /// Alternate names that resolve to this same entry.
  final Set<String> aliases;

  /// The command's broad domain.
  final KnowledgeCategory category;

  /// The platforms on which the command is commonly available.
  final Set<CommandPlatform> platforms;

  /// A short human-readable summary of what the command is.
  final String? description;

  /// Capabilities the command always exercises, regardless of arguments.
  final Set<CommandCapability> baseCapabilities;

  /// The default risk hint for the command, before sub-command or argument
  /// refinement raises it.
  final SecurityLevel baseRisk;

  /// Rules keyed on the first non-flag argument (the sub-command).
  final List<SubcommandRule> subcommands;

  /// Rules keyed on flags or argument patterns.
  final List<ArgumentRule> argumentRules;

  /// If non-null, this command wraps and then executes another command found in
  /// its arguments (e.g. `sudo`, `env`, `xargs`).
  final WrapperSpec? wrapper;

  /// An optional hook for bespoke logic beyond the declarative rules.
  final KnowledgeRefiner? refine;

  /// Every name this entry is registered under: its [executable] plus
  /// [aliases].
  Iterable<String> get allNames => <String>[executable, ...aliases];
}
