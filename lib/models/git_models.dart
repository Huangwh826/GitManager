// lib/models/git_models.dart

// ... (GitFileStatusType, GitFileStatus 保持不变)
enum GitFileStatusType {
  modified,
  added,
  deleted,
  renamed,
  untracked,
}

class GitFileStatus {
  final String path;
  final GitFileStatusType type;
  final bool isStaged;

  GitFileStatus({
    required this.path,
    required this.type,
    this.isStaged = false,
  });
}

// --- GitCommit 类 (完整替换) ---
class GitCommit {
  final String hash;
  final String author;
  final String date;
  final String message;

  /// 新增一个 getter 用于显示简短的哈希值
  String get shortHash => hash.substring(0, 7);

  GitCommit({
    required this.hash,
    required this.author,
    required this.date,
    required this.message,
  });
}
// --- GitCommit 类结束 ---

// ... (GitBranch, RepoDetailState 保持不变)
class GitBranch {
  final String name;
  final bool isLocal;
  final bool isCurrent;
  final String? upstreamInfo;

  GitBranch({
    required this.name,
    required this.isLocal,
    this.isCurrent = false,
    this.upstreamInfo,
  });

  String get displayName {
    if (name.startsWith('remotes/')) {
      return name.substring(name.indexOf('/', 8) + 1);
    }
    return name;
  }
}

class RepoDetailState {
  final List<GitBranch> branches;
  final List<GitCommit> commits;
  final List<GitFileStatus> fileStatus;

  RepoDetailState({
    required this.branches,
    required this.commits,
    required this.fileStatus,
  });
}