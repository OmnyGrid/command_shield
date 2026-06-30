import 'package:meta/meta.dart' show immutable;

/// The operator that joins the commands of a [CommandChain].
enum ChainOperator {
  /// `;` — run each command in order, regardless of exit status.
  sequential,

  /// `&&` — run the next command only if the previous one succeeded.
  and,

  /// `||` — run the next command only if the previous one failed.
  or,
}

/// The kind of I/O redirection described by a [RedirectionNode].
enum RedirectionType {
  /// `>` — truncate-and-write standard output to a file.
  output,

  /// `>>` — append standard output to a file.
  appendOutput,

  /// `<` — read standard input from a file.
  input,

  /// `<<` — here-document: read input until a delimiter.
  hereDocument,

  /// `2>` — truncate-and-write standard error to a file.
  errorOutput,

  /// `2>>` — append standard error to a file.
  appendErrorOutput,

  /// File-descriptor duplication that merges one stream into another, e.g.
  /// `2>&1` (stderr → stdout), `1>&2` (stdout → stderr), `>&2`, or `>&-`
  /// (close fd). No file is written, so this is an innocuous no-op for the
  /// filesystem. [RedirectionNode.target] holds the redirection as written
  /// (e.g. `2>&1`).
  ///
  /// Only single-digit file descriptors are modelled; multi-digit fds such as
  /// `12>&3` are not recognised as merges.
  mergeStreams,

  /// `&>file` / `>&file` — truncate-and-write both stdout and stderr to a
  /// file. Writes the file just like [output].
  combinedOutput,

  /// `&>>file` — append both stdout and stderr to a file. Writes the file
  /// just like [appendOutput].
  combinedAppendOutput,
}

/// The root of the typed command abstract-syntax tree (AST).
///
/// Every parser produces a tree of [CommandNode]s. The hierarchy is `sealed`
/// so analysis code can exhaustively switch over the concrete node types.
///
/// All nodes are immutable and provide structural equality.
@immutable
sealed class CommandNode {
  /// Const base constructor for subclasses.
  const CommandNode();

  /// Visits this node and all of its descendants, depth-first (pre-order).
  ///
  /// The traversal yields this node first, followed by every nested node.
  Iterable<CommandNode> walk() sync* {
    yield this;
    for (final child in children) {
      yield* child.walk();
    }
  }

  /// The direct child nodes of this node, in source order.
  List<CommandNode> get children;
}

/// A single command invocation: an executable plus its arguments.
///
/// Example: `git status` parses to a [CommandInvocation] with
/// `executable == 'git'` and `arguments == ['status']`.
@immutable
final class CommandInvocation extends CommandNode {
  /// Creates a command invocation.
  const CommandInvocation({
    required this.executable,
    this.arguments = const <String>[],
    this.redirections = const <RedirectionNode>[],
    this.substitutions = const <CommandSubstitution>[],
    this.environmentReferences = const <EnvironmentVariableReference>[],
    this.inlineCommand,
  });

  /// The program being invoked, exactly as written (not normalized).
  final String executable;

  /// The arguments passed to [executable], in order, with quoting removed.
  final List<String> arguments;

  /// Redirections attached to this invocation, if any.
  final List<RedirectionNode> redirections;

  /// Command substitutions that appeared within this invocation, if any.
  final List<CommandSubstitution> substitutions;

  /// Environment-variable references that appeared within this invocation.
  final List<EnvironmentVariableReference> environmentReferences;

  /// The command parsed from an inline-execution argument, if this invocation
  /// runs an interpreter on a command string — e.g. the `curl ... | bash` of
  /// `sh -c "curl ... | bash"`, or `cmd /c ...`, `powershell -Command ...`.
  ///
  /// `null` for ordinary invocations. Being a child node, it is visited by
  /// [walk], so the nested command is analyzed like any other command.
  final CommandNode? inlineCommand;

  /// All tokens of the invocation: [executable] followed by [arguments].
  List<String> get tokens => <String>[executable, ...arguments];

  @override
  List<CommandNode> get children => <CommandNode>[
    ...redirections,
    ...substitutions,
    ...environmentReferences,
    ?inlineCommand,
  ];

  @override
  bool operator ==(Object other) =>
      other is CommandInvocation &&
      other.executable == executable &&
      _listEquals(other.arguments, arguments) &&
      _listEquals(other.redirections, redirections) &&
      _listEquals(other.substitutions, substitutions) &&
      _listEquals(other.environmentReferences, environmentReferences) &&
      other.inlineCommand == inlineCommand;

  @override
  int get hashCode => Object.hash(
    executable,
    Object.hashAll(arguments),
    Object.hashAll(redirections),
    Object.hashAll(substitutions),
    Object.hashAll(environmentReferences),
    inlineCommand,
  );

  @override
  String toString() =>
      'CommandInvocation($executable, args: $arguments'
      '${redirections.isEmpty ? '' : ', redirs: $redirections'}'
      '${substitutions.isEmpty ? '' : ', subs: $substitutions'}'
      '${environmentReferences.isEmpty ? '' : ', env: $environmentReferences'}'
      '${inlineCommand == null ? '' : ', inline: $inlineCommand'})';
}

/// A pipeline of commands connected by `|`, where each command's standard
/// output is fed to the next command's standard input.
///
/// Example: `cat file.txt | grep foo | wc -l`.
@immutable
final class Pipeline extends CommandNode {
  /// Creates a pipeline from its [commands].
  const Pipeline(this.commands);

  /// The commands of the pipeline, in left-to-right order. Always contains at
  /// least two elements when produced by a parser.
  final List<CommandNode> commands;

  @override
  List<CommandNode> get children => commands;

  @override
  bool operator ==(Object other) =>
      other is Pipeline && _listEquals(other.commands, commands);

  @override
  int get hashCode => Object.hashAll(commands);

  @override
  String toString() => 'Pipeline($commands)';
}

/// A chain of commands joined by a single [ChainOperator].
///
/// Examples: `git pull && dart test`, `a || b`, `pwd ; ls ; git status`.
@immutable
final class CommandChain extends CommandNode {
  /// Creates a command chain.
  const CommandChain({required this.commands, required this.operator});

  /// The commands being chained, in order.
  final List<CommandNode> commands;

  /// The operator joining [commands].
  final ChainOperator operator;

  @override
  List<CommandNode> get children => commands;

  @override
  bool operator ==(Object other) =>
      other is CommandChain &&
      other.operator == operator &&
      _listEquals(other.commands, commands);

  @override
  int get hashCode => Object.hash(operator, Object.hashAll(commands));

  @override
  String toString() => 'CommandChain(${operator.name}, $commands)';
}

/// A script: an ordered sequence of top-level commands, typically separated by
/// newlines.
@immutable
final class CommandScript extends CommandNode {
  /// Creates a script from its top-level [commands].
  const CommandScript(this.commands);

  /// The top-level commands of the script, in order.
  final List<CommandNode> commands;

  @override
  List<CommandNode> get children => commands;

  @override
  bool operator ==(Object other) =>
      other is CommandScript && _listEquals(other.commands, commands);

  @override
  int get hashCode => Object.hashAll(commands);

  @override
  String toString() => 'CommandScript($commands)';
}

/// An I/O redirection such as `> out.txt`, `>> log`, `< in.txt` or `2> err`.
@immutable
final class RedirectionNode extends CommandNode {
  /// Creates a redirection node.
  const RedirectionNode({required this.type, required this.target});

  /// The kind of redirection.
  final RedirectionType type;

  /// The redirection target (a filename, or here-doc delimiter), as written.
  final String target;

  @override
  List<CommandNode> get children => const <CommandNode>[];

  @override
  bool operator ==(Object other) =>
      other is RedirectionNode && other.type == type && other.target == target;

  @override
  int get hashCode => Object.hash(type, target);

  @override
  String toString() => 'RedirectionNode(${type.name}, $target)';
}

/// A command substitution: `$(...)` or back-tick `` `...` `` whose output is
/// substituted into the surrounding command.
@immutable
final class CommandSubstitution extends CommandNode {
  /// Creates a command substitution wrapping the substituted [command].
  const CommandSubstitution(this.command);

  /// The parsed command whose output is substituted.
  final CommandNode command;

  @override
  List<CommandNode> get children => <CommandNode>[command];

  @override
  bool operator ==(Object other) =>
      other is CommandSubstitution && other.command == command;

  @override
  int get hashCode => command.hashCode;

  @override
  String toString() => 'CommandSubstitution($command)';
}

/// A reference to an environment variable, e.g. `$HOME`, `${HOME}`,
/// `%USERPROFILE%` or `$env:USERPROFILE`.
@immutable
final class EnvironmentVariableReference extends CommandNode {
  /// Creates an environment-variable reference for [variable].
  const EnvironmentVariableReference(this.variable);

  /// The variable name, without any sigils or braces (e.g. `HOME`).
  final String variable;

  @override
  List<CommandNode> get children => const <CommandNode>[];

  @override
  bool operator ==(Object other) =>
      other is EnvironmentVariableReference && other.variable == variable;

  @override
  int get hashCode => variable.hashCode;

  @override
  String toString() => 'EnvironmentVariableReference($variable)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
