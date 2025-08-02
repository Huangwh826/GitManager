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
    if (stderr != null && stderr!.isNotEmpty) {
      return '$message\n$stderr';
    }
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
      final result = await Process.run('git', args, workingDirectory: repoPath, runInShell: true, stdoutEncoding: utf8, stderrEncoding: utf8);

      if (throwOnError && result.exitCode != 0) {
        throw GitCommandException(
          'Git command failed: git ${args.join(' ')}',
          stderr: result.stderr.toString(),
        );
      }
      return result;

    } catch (e) {
      if (e is ProcessException) {
         throw GitCommandException('无法执行 "git"。请确保 Git 已经安装并且在系统的 PATH 环境变量中。', stderr: e.message);
      }
      if (e is GitCommandException) rethrow;
      throw GitCommandException('未知错误: $e');
    }
  }

  /// 检查给定路径是否为一个有效的 Git 仓库。
  Future<bool> isGitRepository() async {
    try {
      final result = await _runGitCommand(['rev-parse', '--is-inside-work-tree'], throwOnError: false);
      return result.exitCode == 0 && result.stdout.toString().trim() == 'true';
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
      else if (xy.startsWith('C')) { // 处理冲突状态
          path = path.split(' -> ').last;
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
      default: return GitFileStatusType.unknown;
    }
  }

  /// 获取提交历史记录。
  Future<List<GitCommit>> getCommits({int maxCount = 50}) async {
    final checkResult = await _runGitCommand(['rev-parse', 'HEAD'], throwOnError: false);
    if (checkResult.exitCode != 0) return [];
    const String separator = 'COMMIT_SEPARATOR_12345';
    const String format = '%H%n%an%n%ar%n%s%nCOMMIT_SEPARATOR_12345';
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
      final lineContent = isCurrent ? line.substring(2) : line.trim();
      final RegExp re = RegExp(r'^\s*([^\s]+)\s+[a-f0-9]+\s*(?:\[([^:]+)(?::\s*(ahead\s+\d+)?(?:,\s*)?(behind\s+\d+)?)?\])?.*$');
      final match = re.firstMatch(lineContent);

      if (match != null) {
        final branchName = match.group(1)!;
        final upstreamInfo = match.group(2);
        int aheadCommits = 0;
        int behindCommits = 0;

        final aheadMatch = RegExp(r'ahead\s+(\d+)').firstMatch(match.group(3) ?? '');
        if (aheadMatch != null) aheadCommits = int.parse(aheadMatch.group(1)!);
        
        final behindMatch = RegExp(r'behind\s+(\d+)').firstMatch(match.group(4) ?? match.group(3) ?? '');
        if (behindMatch != null) behindCommits = int.parse(behindMatch.group(1)!);

        branches.add(GitBranch(
          name: branchName,
          isLocal: !branchName.startsWith('remotes/'),
          isCurrent: isCurrent,
          upstreamInfo: upstreamInfo,
          aheadCommits: aheadCommits,
          behindCommits: behindCommits,
        ));
      }
    }
    return branches;
  }

  Future<void> stageFile(String filePath) async => _runGitCommand(['add', filePath]);
  Future<void> unstageFile(String filePath) async => _runGitCommand(['reset', 'HEAD', '--', filePath]);

  /// 批量暂存多个文件
  Future<void> stageFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    await _runGitCommand(['add', '--', ...filePaths]);
  }

  /// 批量取消暂存多个文件
  Future<void> unstageFiles(List<String> filePaths) async {
    if (filePaths.isEmpty) return;
    await _runGitCommand(['reset', 'HEAD', '--', ...filePaths]);
  }
  Future<void> commit(String message) async {
    if (message.trim().isEmpty) throw GitCommandException('提交信息不能为空。');
    await _runGitCommand(['commit', '-m', message]);
  }
  Future<void> switchBranch(String branchName) async => _runGitCommand(['checkout', branchName]);
  Future<String> getDiff(String filePath, {bool isStaged = false}) async {
    final args = isStaged ? ['diff', '--cached', '--', filePath] : ['diff', '--', filePath];
    final result = await _runGitCommand(args, throwOnError: false);

    if(result.exitCode != 0){
        return "加载差异失败: ${result.stderr}";
    }

    final diffOutput = result.stdout.toString();
    if (diffOutput.isNotEmpty) {
      return diffOutput;
    }

    // 如果没有差异，检查文件是否是新增的
    try {
      final file = File('$repoPath/$filePath');
      if (await file.exists()) {
        final content = await file.readAsString();
        // 为新增文件生成模拟差异
        return 'diff --git a/$filePath b/$filePath\nnew file mode 100644\nindex 0000000..1234567\n--- /dev/null\n+++ b/$filePath\n@@ -0,0 +1,${content.split('\n').length} @@\n${content.split('\n').map((line) => '+$line').join('\n')}';
      }
    } catch (e) {
      return "无法读取文件内容: ${e.toString()}";
    }

    return "没有检测到差异。";
  }
  Future<RepoDetailState> getFullRepoState() async {
    if (!await isGitRepository()) throw GitCommandException('这不是一个有效的 Git 仓库。');
    final results = await Future.wait([getBranches(), getCommits(), getStatus()]);
    return RepoDetailState(
      branches: results[0] as List<GitBranch>,
      commits: results[1] as List<GitCommit>,
      fileStatus: results[2] as List<GitFileStatus>,
    );
  }
  Future<void> fetch() async => _runGitCommand(['fetch', '--all', '--prune']);
  Future<void> pull() async => _runGitCommand(['pull']);
  Future<void> push() async => _runGitCommand(['push']);
  Future<void> initRepository() async => _runGitCommand(['init']);
  Future<void> createBranch(String branchName) async {
    if (branchName.trim().isEmpty) throw GitCommandException('分支名称不能为空。');
    await _runGitCommand(['checkout', '-b', branchName]);
  }

  Future<List<RemoteRepository>> getRemotes() async {
    final result = await _runGitCommand(['remote', '-v']);
    final List<RemoteRepository> remotes = [];
    final lines = result.stdout.toString().split('\n');
    final Map<String, String> remoteUrls = {};

    for (var line in lines) {
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 3 || parts[2] != '(fetch)') continue;
      final name = parts[0];
      final url = parts[1];
      remoteUrls[name] = url;
    }

    remoteUrls.forEach((name, url) {
      remotes.add(RemoteRepository(name: name, url: url));
    });

    return remotes;
  }

  Future<void> addRemote(String name, String url) async {
    if (name.trim().isEmpty || url.trim().isEmpty) {
      throw GitCommandException('远程仓库名称和URL不能为空。');
    }
    await _runGitCommand(['remote', 'add', name, url]);
  }

  Future<void> removeRemote(String name) async {
    if (name.trim().isEmpty) throw GitCommandException('远程仓库名称不能为空。');
    await _runGitCommand(['remote', 'remove', name]);
  }

  Future<void> setRemoteUrl(String name, String newUrl) async {
    if (name.trim().isEmpty || newUrl.trim().isEmpty) {
      throw GitCommandException('远程仓库名称和URL不能为空。');
    }
    await _runGitCommand(['remote', 'set-url', name, newUrl]);
  }

  Future<void> stash(String message) async {
    if (message.trim().isEmpty) {
      await _runGitCommand(['stash', 'push']);
    } else {
      await _runGitCommand(['stash', 'push', '-m', message]);
    }
  }

  Future<List<GitStash>> getStashes() async {
    const String separator = '<<stash_entry_separator>>';
    const String format = '%gd|%an|%ar|%s$separator';
    final result = await _runGitCommand(['log', '-g', 'refs/stashes', '--pretty=format:$format'], throwOnError: false);

    final List<GitStash> stashes = [];
    if (result.stdout.toString().isEmpty) {
      return stashes;
    }

    final stashStrings = result.stdout.toString().split(separator);

    for (var stashString in stashStrings) {
      if (stashString.trim().isEmpty) continue;
      final parts = stashString.trim().split('|');
      if (parts.length >= 4) {
        stashes.add(GitStash(
          ref: parts[0].trim(),
          name: parts[0].trim(),
          author: parts[1].trim(),
          date: parts[2].trim(),
          message: parts.sublist(3).join('|').trim(),
          // ref is the same as name for stashes
        ));
      }
    }
    return stashes;
  }

  Future<void> applyStash(String stashRef) async => _runGitCommand(['stash', 'apply', stashRef]);
  Future<void> dropStash(String stashRef) async => _runGitCommand(['stash', 'drop', stashRef]);
  Future<void> cherryPick(String commitHash) async => _runGitCommand(['cherry-pick', commitHash]);
  Future<void> abortMerge() async => _runGitCommand(['merge', '--abort']);

  Future<List<String>> getConflictFiles() async {
    final result = await _runGitCommand(['diff', '--name-only', '--diff-filter=U'], throwOnError: false);
    return result.stdout.toString().split('\n').where((file) => file.isNotEmpty).toList();
  }

  Future<String?> getFileWithConflicts(String filePath) async {
    try {
      final file = File('$repoPath/$filePath');
      return await file.exists() ? await file.readAsString() : null;
    } catch (e) {
      throw GitCommandException('读取冲突文件失败', stderr: e.toString());
    }
  }

  Future<void> resolveConflict(String filePath, String resolvedContent) async {
    final file = File('$repoPath/$filePath');
    await file.writeAsString(resolvedContent);
    await _runGitCommand(['add', filePath]);
  }

  /// 获取单次提交的详细信息。
  Future<GitCommitDetail> getCommitDetails(String hash) async {
    final result = await _runGitCommand(['show', hash, '--patch-with-stat', '--pretty=fuller', '--date=iso-strict']);
    final output = result.stdout.toString();

    // ... (解析逻辑保持不变)
    String author = '', authorDate = '', committer = '', commitDate = '', message = '';
    String authorEmail = '';
    final List<String> parents = [];
    final lines = output.split('\n');
    int lineIndex = 0;

    // ... 解析头部信息 ...

    while (lineIndex < lines.length) {
        final line = lines[lineIndex];
        if (line.startsWith('Author:')) {
            final match = RegExp(r'Author:\s*(.*)\s*<([^>]+)>').firstMatch(line);
            author = match?.group(1)?.trim() ?? '';
            authorEmail = match?.group(2)?.trim() ?? '';
        } else if (line.startsWith('AuthorDate:')) {
            authorDate = line.substring('AuthorDate:'.length).trim();
        } else if (line.startsWith('Commit:')) {
            final match = RegExp(r'Commit:\s*(.*)\s*<([^>]+)>').firstMatch(line);
            committer = match?.group(1)?.trim() ?? '';
        } else if (line.startsWith('CommitDate:')) {
            commitDate = line.substring('CommitDate:'.length).trim();
        } else if (line.startsWith('parent ')) {
            parents.add(line.substring('parent '.length).trim());
        } else if (line.isEmpty) {
            lineIndex++;
            break; 
        }
        lineIndex++;
    }

    final messageLines = <String>[];
    while(lineIndex < lines.length) {
        final line = lines[lineIndex];
        if (line.startsWith('diff --git')) break;
        messageLines.add(line.trimLeft());
        lineIndex++;
    }
    message = messageLines.join('\n').trim();

    // ... 解析文件差异 ...
    final List<GitFileDiff> files = [];
    final diffOutput = lines.sublist(lineIndex).join('\n');
    final diffs = diffOutput.split(RegExp(r'\ndiff --git '))..removeWhere((d) => d.isEmpty);

    for (var diffBlock in diffs) {
        final lines = diffBlock.split('\n');
        final pathLine = lines.first;
        final path = pathLine.split(' b/').last.trim();
        String statusString = 'modified';
        int additions = 0;
        int deletions = 0;

        if (diffBlock.contains('\nnew file mode')) statusString = 'added';
        else if (diffBlock.contains('\ndeleted file mode')) statusString = 'deleted';
        else if (diffBlock.contains('\nrename from')) statusString = 'renamed';
        
        final statLine = lines.firstWhere((l) => l.startsWith(' ' + path), orElse: () => '');
        if (statLine.isNotEmpty) {
            final statMatch = RegExp(r'(\d+)\s+([+-]+)').firstMatch(statLine);
            if (statMatch != null) {
                final changes = statMatch.group(2)!;
                additions = '+'.allMatches(changes).length;
                deletions = '-'.allMatches(changes).length;
            }
        }

        files.add(GitFileDiff(
            path: path,
            type: _parseStatusType(statusString.substring(0,1).toUpperCase()),
            diffContent: 'diff --git ' + diffBlock,
            additions: additions,
            deletions: deletions,
        ));
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
      insertions: files.fold(0, (sum, f) => sum + f.additions),
      deletions: files.fold(0, (sum, f) => sum + f.deletions),
    );
  }
}