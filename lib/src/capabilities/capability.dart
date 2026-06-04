/// A discrete capability a command may exercise.
///
/// A single command may have several capabilities (for example, `git push`
/// both reads the filesystem and writes to the network).
enum CommandCapability {
  /// Reads files or directory metadata from the filesystem.
  readFilesystem,

  /// Creates or modifies files on the filesystem.
  writeFilesystem,

  /// Removes files or directories from the filesystem.
  deleteFilesystem,

  /// Executes other programs or interprets code.
  executePrograms,

  /// Reads data from the network (downloads, fetches, clones).
  networkRead,

  /// Sends data over the network (uploads, pushes, posts).
  networkWrite,

  /// Inspects or controls operating-system processes.
  processManagement,

  /// Escalates privileges (e.g. `sudo`, `su`, `runas`).
  privilegeEscalation,

  /// Changes system or security configuration (permissions, ownership,
  /// services, registry).
  systemConfiguration,

  /// Reads or expands environment variables.
  environmentAccess,
}
