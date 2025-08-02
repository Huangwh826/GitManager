// lib/services/git_service.dart

import 'dart:io';
import 'dart:convert';
import '../models/git_models.dart';

/// 一个自定义异常类，用于封装 Git 命令执行失败时的信息。
class GitCommandException implements Exception {
  final String message;
  final String? stderr;

  GitCommandException(this.message, {this.stderr});

  @override
  String toString() {
    return message;
  }
}

/// GitService 负责执行所有 git 命令并解析其输出。
class GitService {
  final String repoPath;

  GitService({required this.repoPath});

  /// 辅助函数，用于执行 git 命令并处理通用错误。
  /// (核心修正) 使用 Future.wait 并行处理流，防止死锁。
  Future<ProcessResult> _runGitCommand(List<String> args, {bool throwOnError = true}) async {
    try {
      final process = await Process.start('git', args, workingDirectory: repoPath);

      // 并行等待进程退出和流的读取
      final results = await Future.wait([
        process.exitCode,
        process.stdout.fold<List<int>>([], (p, e) => p..addAll(e)),
        process.stderr.fold<List<int>>([], (p, e) => p..addAll(e)),
      ]);

      final exitCode = results[0] as int;
      final stdoutBytes = results[1] as List<int>;
      final stderrBytes = results[2] as List<int>;

      final stdoutStr = utf8.decode(stdoutBytes);
      final stderrStr = utf8.decode(stderrBytes);

      if (throwOnError && exitCode != 0) {
        throw GitCommandException(
          'Git command failed: git ${args.join(' ')}',
          stderr: stderrStr,
        );
      }

      return ProcessResult(process.pid, exitCode, stdoutStr, stderrStr);

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
  Future<List<GitCommit>> getCommits({int maxCount = 50}) async {
    final checkResult = await _runGitCommand(['rev-parse', 'HEAD'], throwOnError: false);
    if (checkResult.exitCode != 0) return [];
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
  Future<List<GitBranch>> getBranches() async {
    final result = await _runGitCommand(['branch', '-a', '-vv', '--no-color'], throwOnError: false);
    if (result.exitCode != 0) return [];
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

  Future<void> stageFile(String filePath) async => _runGitCommand(['add', filePath]);
  Future<void> unstageFile(String filePath) async => _runGitCommand(['reset', 'HEAD', '--', filePath]);
  Future<void> commit(String message) async {
    if (message.trim().isEmpty) throw GitCommandException('提交信息不能为空。');
    await _runGitCommand(['commit', '-m', message]);
  }
  Future<void> switchBranch(String branchName) async => _runGitCommand(['checkout', branchName]);
  Future<String> getDiff(String filePath, {bool isStaged = false}) async {
    final args = isStaged ? ['diff', '--cached', '--', filePath] : ['diff', '--', filePath];
    final result = await _runGitCommand(args);
    return result.stdout.toString().isEmpty ? "没有检测到差异。" : result.stdout.toString();
  }
  Future<RepoDetailState> getFullRepoState() async {
    if (!await isGitRepository()) throw GitCommandException('这不是一个 Git 仓库。');
    final results = await Future.wait([getBranches(), getCommits(), getStatus()]);
    return RepoDetailState(
      branches: results[0] as List<GitBranch>,
      commits: results[1] as List<GitCommit>,
      fileStatus: results[2] as List<GitFileStatus>,
    );
  }
  Future<void> fetch() async => _runGitCommand(['fetch']);
  Future<void> pull() async => _runGitCommand(['pull']);
  Future<void> push() async => _runGitCommand(['push']);
  Future<void> initRepository() async => _runGitCommand(['init']);
  Future<void> createBranch(String branchName) async {
    if (branchName.trim().isEmpty) throw GitCommandException('分支名称不能为空。');
    await _runGitCommand(['checkout', '-b', branchName]);
  }

  /// 获取所有远程仓库
  Future<List<RemoteRepository>> getRemotes() async {
    final result = await _runGitCommand(['remote', '-v']);
    final List<RemoteRepository> remotes = [];
    final lines = result.stdout.toString().split('\n');
    final Map<String, String> remoteUrls = {};

    for (var line in lines) {
      if (line.isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 2) continue;
      final name = parts[0];
      final url = parts[1].split(' ')[0];
      remoteUrls[name] = url;
    }

    remoteUrls.forEach((name, url) {
      remotes.add(RemoteRepository(name: name, url: url));
    });

    return remotes;
  }

  /// 添加远程仓库
  Future<void> addRemote(String name, String url) async {
    if (name.trim().isEmpty || url.trim().isEmpty) {
      throw GitCommandException('远程仓库名称和URL不能为空。');
    }
    await _runGitCommand(['remote', 'add', name, url]);
  }

  /// 删除远程仓库
  Future<void> removeRemote(String name) async {
    if (name.trim().isEmpty) throw GitCommandException('远程仓库名称不能为空。');
    await _runGitCommand(['remote', 'remove', name]);
  }

  /// 更新远程仓库URL
  Future<void> setRemoteUrl(String name, String newUrl) async {
    if (name.trim().isEmpty || newUrl.trim().isEmpty) {
      throw GitCommandException('远程仓库名称和URL不能为空。');
    }
    await _runGitCommand(['remote', 'set-url', name, newUrl]);
  }

  /// 存储当前工作区的变更 (已修复)
  Future<void> stash(String message) async {
    // 使用 'push' 代替过时的 'save'，并使用 -m 标志来添加消息
    if (message.trim().isEmpty) {
      await _runGitCommand(['stash', 'push']);
    } else {
      await _runGitCommand(['stash', 'push', '-m', message]);
    }
  }

  /// 列出所有stash (已修复)
  Future<List<GitStash>> getStashes() async {
    // 使用 `git log -g refs/stashes` 来获取详细的 stash 信息
    // 使用一个几乎不可能出现在提交信息中的分隔符
    const String separator = '<<stash_entry_separator>>';
    // 格式: refName|authorName|authorDateRelative|message
    const String format = '%gd|%an|%ar|%s$separator';
    final result = await _runGitCommand(['log', '-g', 'refs/stashes', '--pretty=format:$format'], throwOnError: false);

    final List<GitStash> stashes = [];
    if (result.stdout.toString().isEmpty) {
      return stashes;
    }

    final stashStrings = result.stdout.toString().split(separator);

    for (var stashString in stashStrings) {
      if (stashString.trim().isEmpty) continue;

      // 使用'|'作为分隔符进行分割
      final parts = stashString.trim().split('|');
      if (parts.length >= 4) {
        final ref = parts[0].trim();       // 例如: stash@{0}
        final author = parts[1].trim();
        final date = parts[2].trim();
        // 消息可能是多部分，合并剩余部分
        final message = parts.sublist(3).join('|').trim();

        stashes.add(GitStash(
          // 根据模型和视图的使用情况，name 和 ref 都设置为 stash 的引用
          name: ref,
          ref: ref,
          author: author,
          date: date,
          message: message,
        ));
      }
    }
    return stashes;
  }


  /// 应用指定的stash
  Future<void> applyStash(String stashRef) async {
    await _runGitCommand(['stash', 'apply', stashRef]);
  }

  /// 删除指定的stash
  Future<void> dropStash(String stashRef) async {
    await _runGitCommand(['stash', 'drop', stashRef]);
  }

  /// cherry-pick指定的提交
  Future<void> cherryPick(String commitHash) async {
    await _runGitCommand(['cherry-pick', commitHash]);
  }

  // 合并冲突解决功能已移至下面的resolveConflict方法
  /// 中止合并
  Future<void> abortMerge() async {
    await _runGitCommand(['merge', '--abort']);
  }

  // 获取所有冲突文件
  Future<List<String>> getConflictFiles() async {
    final result = await _runGitCommand(['diff', '--name-only', '--diff-filter=U']);
    return result.stdout.toString().split('\n').where((file) => file.isNotEmpty).toList();
  }

  // 获取包含冲突的文件内容
  Future<String?> getFileWithConflicts(String filePath) async {
    try {
      final file = File('$repoPath/$filePath');
      if (!file.existsSync()) {
        throw Exception('文件不存在: $filePath');
      }
      return await file.readAsString();
    } catch (e) {
      print('读取冲突文件失败: $e');
      throw e;
    }
  }

  // 解决冲突
  // 解决冲突并将文件添加到暂存区
  Future<void> resolveConflict(String filePath, String resolvedContent) async {
    try {
      final file = File('$repoPath/$filePath');
      if (!file.existsSync()) {
        throw Exception('文件不存在: $filePath');
      }
      await file.writeAsString(resolvedContent);
      // 将解决后的文件添加到暂存区
      await _runGitCommand(['add', filePath]);
    } catch (e) {
      print('解决冲突失败: $e');
      throw e;
    }
  }

  /// 获取单次提交的详细信息。
  Future<GitCommitDetail> getCommitDetails(String hash) async {
    final result = await _runGitCommand(['show', hash, '--patch-with-stat', '--pretty=fuller']);
    final output = result.stdout.toString();

    String author = '', authorDate = '', committer = '', commitDate = '', message = '';
    String authorEmail = '', committerEmail = '';
    final List<String> parents = [];
    final lines = output.split('\n');
    int lineIndex = 0;
    while(lineIndex < lines.length) {
      final line = lines[lineIndex];
      if (line.startsWith('Author:')) {
        final authorMatch = RegExp(r'Author: (.*) <(.*)>').firstMatch(line);
        author = authorMatch?.group(1)?.trim() ?? line.substring(8).trim();
        authorEmail = authorMatch?.group(2)?.trim() ?? '';
      }
      if (line.startsWith('AuthorDate:')) authorDate = line.substring(12).trim();
      if (line.startsWith('Commit:')) {
        final committerMatch = RegExp(r'Commit: (.*) <(.*)>').firstMatch(line);
        committer = committerMatch?.group(1)?.trim() ?? line.substring(8).trim();
        committerEmail = committerMatch?.group(2)?.trim() ?? authorEmail;
      }
      if (line.startsWith('CommitDate:')) commitDate = line.substring(12).trim();
      if (line.startsWith('parent ')) {
        parents.add(line.substring('parent '.length).trim());
      }
      if (line.isEmpty) { lineIndex++; break; }
      lineIndex++;
    }

    final messageLines = <String>[];
    while(lineIndex < lines.length) {
      final line = lines[lineIndex];
      if (line.startsWith('diff --git')) break;
      messageLines.add(line.trim());
      lineIndex++;
    }
    message = messageLines.join('\n').trim();

    final List<GitFileDiff> files = [];
    final diffOutput = lines.sublist(lineIndex).join('\n');
    final diffs = diffOutput.split('diff --git');

    for (var diffBlock in diffs) {
      if (diffBlock.trim().isEmpty) continue;
      final diffLines = diffBlock.split('\n');
      final pathLine = diffLines.first;
      final path = pathLine.split(' b/').last.trim();
      GitFileStatusType type = GitFileStatusType.modified;
      int additions = 0;
      int deletions = 0;

      // 确定文件变更类型
      if (diffBlock.contains('new file mode')) {
        type = GitFileStatusType.added;
      } else if (diffBlock.contains('deleted file mode')) {
        type = GitFileStatusType.deleted;
      } else if (diffBlock.startsWith('rename from')) {
        type = GitFileStatusType.renamed;
      }

      // 解析变更统计信息
      final statLine = diffLines.lastWhere((line) => line.contains('+') && line.contains('-'), orElse: () => '');
      if (statLine.isNotEmpty) {
        final RegExp regExp = RegExp(r'(\d+) insertion.* (\d+) deletion');
        final match = regExp.firstMatch(statLine);
        if (match != null) {
          additions = int.tryParse(match.group(1)!) ?? 0;
          deletions = int.tryParse(match.group(2)!) ?? 0;
        } else {
          // 处理只有新增或只有删除的情况
          if (statLine.contains('insertion')) {
            final RegExp addRegExp = RegExp(r'(\d+) insertion');
            final addMatch = addRegExp.firstMatch(statLine);
            additions = addMatch != null ? int.tryParse(addMatch.group(1)!) ?? 0 : 0;
          } else if (statLine.contains('deletion')) {
            final RegExp delRegExp = RegExp(r'(\d+) deletion');
            final delMatch = delRegExp.firstMatch(statLine);
            deletions = delMatch != null ? int.tryParse(delMatch.group(1)!) ?? 0 : 0;
          }
        }
      }

      files.add(GitFileDiff(
        path: path,
        type: type,
        diffContent: 'diff --git $diffBlock',
        additions: additions,
        deletions: deletions,
      ));
    }

    // 计算总插入和删除行数
    int insertions = 0;
    int deletions = 0;
    for (final file in files) {
      insertions += file.additions;
      deletions += file.deletions;
    }

    return GitCommitDetail(
      hash: hash,
      author: author,
      date: authorDate,
      message: message,
      committer: committer,
      committerDate: commitDate,
      files: files,
      authorEmail: authorEmail,
      parents: parents,
      insertions: insertions,
      deletions: deletions,
    );
  }
}