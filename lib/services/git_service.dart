// lib/services/git_service.dart

import 'dart:io';

import '../models/git_models.dart';

/// 一个自定义异常类，用于封装 Git 命令执行失败时的信息。
class GitCommandException implements Exception {
  final String message;
  final String? stderr;

  GitCommandException(this.message, {this.stderr});

  @override
  String toString() {
    // 简化错误信息的显示
    return message;
  }
}

/// GitService 负责执行所有 git 命令并解析其输出。
class GitService {
  final String repoPath;

  GitService({required this.repoPath});

  /// 辅助函数，用于执行 git 命令并处理通用错误。
  Future<ProcessResult> _runGitCommand(List<String> args, {bool throwOnError = true}) async {
    try {
      final result = await Process.run('git', args, workingDirectory: repoPath);
      if (throwOnError && result.exitCode != 0) {
        throw GitCommandException(
          'Git command failed: git ${args.join(' ')}',
          stderr: result.stderr.toString(),
        );
      }
      return result;
    } catch (e) {
      if (e is GitCommandException) rethrow;
      throw GitCommandException('Failed to execute git. Is Git installed and in your PATH?');
    }
  }

  /// 检查给定路径是否为一个有效的 Git 仓库。
  Future<bool> isGitRepository() async {
    try {
      final gitDir = Directory('${repoPath}${Platform.pathSeparator}.git');
      return await gitDir.exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取当前仓库的文件状态。
  Future<List<GitFileStatus>> getStatus() async {
    final result = await _runGitCommand(['status', '--porcelain=v1', '--untracked-files=all']);
    final List<GitFileStatus> files = [];
    final lines = result.stdout.toString().split('\n');

    for (var line in lines) {
      if (line.isEmpty) continue;
      String xy = line.substring(0, 2);
      String path = line.substring(3);
      if (xy.startsWith('R')) {
        final parts = path.split(' -> ');
        path = parts.length > 1 ? parts[1] : parts[0];
      }
      String stagedStatus = xy[0];
      if (stagedStatus != ' ' && stagedStatus != '?') {
        files.add(GitFileStatus(path: path, type: _parseStatusType(stagedStatus), isStaged: true));
      }
      String unstagedStatus = xy[1];
      if (unstagedStatus != ' ') {
        files.add(GitFileStatus(path: path, type: _parseStatusType(unstagedStatus), isStaged: false));
      }
    }
    return files;
  }

  GitFileStatusType _parseStatusType(String char) {
    switch (char) {
      case 'M': return GitFileStatusType.modified;
      case 'A': return GitFileStatusType.added;
      case 'D': return GitFileStatusType.deleted;
      case 'R': return GitFileStatusType.renamed;
      case '?': return GitFileStatusType.untracked;
      default: return GitFileStatusType.untracked;
    }
  }

  /// 获取提交历史记录。
  /// (核心修改) 对空仓库进行特殊处理，避免抛出异常。
  Future<List<GitCommit>> getCommits({int maxCount = 50}) async {
    // 检查仓库是否为空（没有任何提交）
    final checkResult = await _runGitCommand(['rev-parse', 'HEAD'], throwOnError: false);
    if (checkResult.exitCode != 0) {
      // 如果 HEAD 不存在，说明没有提交，直接返回空列表
      return [];
    }

    const String separator = '<<commit_separator>>';
    const String format = '%H%n%an%n%ar%n%s%n$separator';
    final result = await _runGitCommand(['log', '--pretty=format:$format', '--max-count=$maxCount']);

    final List<GitCommit> commits = [];
    final commitStrings = result.stdout.toString().split(separator);

    for (var commitString in commitStrings) {
      if (commitString.trim().isEmpty) continue;
      final lines = commitString.trim().split('\n');
      if (lines.length >= 4) {
        commits.add(GitCommit(
          hash: lines[0],
          author: lines[1],
          date: lines[2],
          message: lines.sublist(3).join('\n'),
        ));
      }
    }
    return commits;
  }

  /// 获取所有本地和远程分支。
  /// (核心修改) 对空仓库进行特殊处理。
  Future<List<GitBranch>> getBranches() async {
    final result = await _runGitCommand(['branch', '-a', '-vv', '--no-color'], throwOnError: false);
    // 如果命令失败（例如在空仓库中），直接返回空列表
    if (result.exitCode != 0) {
      return [];
    }

    final List<GitBranch> branches = [];
    final lines = result.stdout.toString().split('\n');

    for (var line in lines) {
      if (line.isEmpty || line.contains('->')) continue;
      final isCurrent = line.startsWith('*');
      final lineContent = isCurrent ? line.substring(2) : line;
      final RegExp re = RegExp(r'^\s*([^\s]+)\s+[a-f0-9]+\s*(?:\[([^\]]+)\])?.*$');
      final match = re.firstMatch(lineContent);

      if (match != null) {
        final branchName = match.group(1)!;
        final upstreamInfo = match.group(2);
        branches.add(GitBranch(
          name: branchName,
          isLocal: !branchName.startsWith('remotes/'),
          isCurrent: isCurrent,
          upstreamInfo: upstreamInfo,
        ));
      }
    }
    return branches;
  }

  /// 暂存文件。
  Future<void> stageFile(String filePath) async {
    await _runGitCommand(['add', filePath]);
  }

  /// 取消暂存文件。
  Future<void> unstageFile(String filePath) async {
    await _runGitCommand(['reset', 'HEAD', '--', filePath]);
  }

  /// 提交。
  Future<void> commit(String message) async {
    if (message.trim().isEmpty) {
      throw GitCommandException('提交信息不能为空。');
    }
    await _runGitCommand(['commit', '-m', message]);
  }

  /// 切换分支。
  Future<void> switchBranch(String branchName) async {
    await _runGitCommand(['checkout', branchName]);
  }

  /// 获取文件差异。
  Future<String> getDiff(String filePath, {bool isStaged = false}) async {
    final args = isStaged
        ? ['diff', '--cached', '--', filePath]
        : ['diff', '--', filePath];
    final result = await _runGitCommand(args);
    return result.stdout.toString().isEmpty
        ? "没有检测到差异。"
        : result.stdout.toString();
  }

  /// 并行获取仓库的所有核心状态。
  Future<RepoDetailState> getFullRepoState() async {
    if (!await isGitRepository()) {
      throw GitCommandException('这不是一个 Git 仓库。');
    }
    final results = await Future.wait([
      getBranches(),
      getCommits(),
      getStatus(),
    ]);
    return RepoDetailState(
      branches: results[0] as List<GitBranch>,
      commits: results[1] as List<GitCommit>,
      fileStatus: results[2] as List<GitFileStatus>,
    );
  }

  /// 从默认远程仓库抓取最新数据。
  Future<void> fetch() async {
    await _runGitCommand(['fetch']);
  }

  /// 拉取当前分支上游的最新更改。
  Future<void> pull() async {
    await _runGitCommand(['pull']);
  }

  /// 推送当前分支到其上游分支。
  Future<void> push() async {
    await _runGitCommand(['push']);
  }

  /// 在当前仓库路径下初始化一个新的 Git 仓库。
  Future<void> initRepository() async {
    await _runGitCommand(['init']);
  }
}