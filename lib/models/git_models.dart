// lib/models/git_models.dart

// Git 文件状态的枚举
enum GitFileStatusType {
  modified,
  added,
  deleted,
  renamed,
  untracked,
}

// 代表一个文件的状态
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

// 代表一次 Git 提交记录 (列表项)
class GitCommit {
  final String hash;
  final String author;
  final String date;
  final String message;

  String get shortHash => hash.substring(0, 7);

  GitCommit({
    required this.hash,
    required this.author,
    required this.date,
    required this.message,
  });
}

// 代表一个 Git 分支
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

// --- 新增部分开始 ---

/// 代表在一次提交中，单个文件的变更情况
class GitFileDiff {
  final String path;
  final GitFileStatusType type;
  final String diffContent;

  GitFileDiff({
    required this.path,
    required this.type,
    required this.diffContent,
  });
}

/// 代表一次提交的完整详细信息
class GitCommitDetail extends GitCommit {
  final String committer;
  final String committerDate;
  final List<GitFileDiff> files;

  GitCommitDetail({
    required super.hash,
    required super.author,
    required super.date,
    required super.message,
    required this.committer,
    required this.committerDate,
    required this.files,
  });
}
// --- 新增部分结束 ---


// 一个聚合类，用于封装仓库详情视图所需的所有状态。
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