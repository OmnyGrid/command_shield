import '../../capability.dart';
import '../command_knowledge.dart';
import '../command_knowledge_plugin.dart';
import 'knowledge_builders.dart';

/// Knowledge about shells, language interpreters/build tools, and the wrapper
/// commands that re-dispatch to another command in their arguments.
final class ShellKnowledge implements CommandKnowledgePlugin {
  /// Creates the shell knowledge plugin.
  const ShellKnowledge();

  @override
  String get name => 'shell';

  @override
  List<CommandKnowledge> get entries => [
    // --- shells & interpreters & build tools (execute code) ---
    ...simpleEntries(
      const [
        'bash',
        'sh',
        'zsh',
        'dash',
        'ksh',
        'fish',
        'csh',
        'tcsh',
        'python',
        'python3',
        'node',
        'ruby',
        'perl',
        'php',
        'java',
        'npx',
        'make',
        'gcc',
        'clang',
        'cc',
        'eval',
        'source',
        'cmd',
        'powershell',
        'pwsh',
        'deno',
        'dotnet',
        'mvn',
        'gradle',
        'rake',
        'lua',
        'osascript',
        'rscript',
        'swift',
        'kotlin',
        'scala',
        'invoke-expression',
        'iex',
        // build systems & task runners
        'cmake',
        'ninja',
        'meson',
        'bazel',
        'buck2',
        'just',
        'task',
        'ant',
        'sbt',
        'lein',
        'clj',
        'clojure',
        'mix',
        'cabal',
        'stack',
        'ghc',
        'runghc',
        'runhaskell',
        'erl',
        'elixir',
        'groovy',
        'jshell',
        // JS/TS toolchain
        'tsc',
        'ts-node',
        'tsx',
        'babel',
        'webpack',
        'vite',
        'rollup',
        'esbuild',
        'parcel',
        'gulp',
        'grunt',
        'bunx',
        'uvx',
        // test runners
        'pytest',
        'tox',
        'nox',
        'jest',
        'mocha',
        // other interpreters/compilers
        'julia',
        'expect',
        'tclsh',
        'wish',
        'zig',
        'nim',
        'crystal',
        'raku',
        'busybox',
        // run-on-change / multiplexers (execute commands)
        'entr',
        'inotifywait',
        'fswatch',
        'screen',
        'tmux',
      ],
      KnowledgeCategory.interpreter,
      const {CommandCapability.executePrograms},
    ),

    // --- privilege-escalation wrappers ---
    for (final w in const ['sudo', 'su', 'doas', 'pkexec', 'runas'])
      CommandKnowledge(
        executable: w,
        category: KnowledgeCategory.shell,
        description: 'Runs a command with elevated privileges.',
        baseCapabilities: const {CommandCapability.privilegeEscalation},
        wrapper: const WrapperSpec(),
      ),

    // --- plain command wrappers ---
    for (final w in const [
      'xargs',
      'time',
      'nohup',
      'timeout',
      'watch',
      'exec',
      'builtin',
      'stdbuf',
    ])
      CommandKnowledge(
        executable: w,
        category: KnowledgeCategory.shell,
        description: 'Wraps and executes another command.',
        wrapper: const WrapperSpec(),
      ),

    // `command` runs the wrapped command, but `command -v`/`-V` only looks it
    // up (like `which`/`type`) without executing it.
    const CommandKnowledge(
      executable: 'command',
      category: KnowledgeCategory.shell,
      description: 'Runs a command, or looks one up with -v/-V.',
      wrapper: WrapperSpec(lookupFlags: {'-v', '-V'}),
    ),

    // `nice` both adjusts scheduling priority and wraps a command.
    const CommandKnowledge(
      executable: 'nice',
      category: KnowledgeCategory.process,
      description: 'Runs a command at an adjusted scheduling priority.',
      baseCapabilities: {CommandCapability.processManagement},
      wrapper: WrapperSpec(),
    ),

    // --- env: wrapper that also skips NAME=VALUE assignments ---
    const CommandKnowledge(
      executable: 'env',
      category: KnowledgeCategory.environment,
      description: 'Runs a command in a modified environment.',
      baseCapabilities: {CommandCapability.environmentAccess},
      wrapper: WrapperSpec(skipAssignments: true),
    ),
  ];
}
