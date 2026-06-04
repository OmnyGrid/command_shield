/// A human-readable, high-level summary of what a command does.
///
/// Effects are derived from command capabilities and provide a coarser, more
/// explainable view suitable for surfacing to users and agents.
enum CommandEffect {
  /// The command only reads data; it does not change anything.
  readOnly,

  /// The command creates or modifies files.
  modifyFiles,

  /// The command removes files or directories.
  deleteFiles,

  /// The command executes other programs or interprets code.
  executeCode,

  /// The command reads from or writes to the network.
  networkAccess,

  /// The command changes system or security configuration.
  systemModification,

  /// The command escalates privileges.
  privilegeEscalation,
}
