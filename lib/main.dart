// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import 'services/repository_service.dart';
import 'services/git_service.dart';
import 'models/git_models.dart';
import 'widgets/commit_view.dart';
import 'widgets/branch_list_view.dart';
import 'widgets/diff_view.dart';
import 'widgets/commit_history_view.dart';
import 'widgets/staging_area_view.dart';
import 'widgets/commit_detail_view.dart'; // 新增引入

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => RepositoryService(),
      child: const GitManagerApp(),
    ),
  );
}

class GitManagerApp extends StatelessWidget {
  const GitManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitManager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1F2937),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
        ),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<_RepositoryDetailViewState> _repoDetailViewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final repoService = Provider.of<RepositoryService>(context);
    final selectedRepoPath = repoService.selectedRepositoryPath;

    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.history_toggle_off, color: Colors.blueAccent),
        title: DropdownButton<String>(
          value: selectedRepoPath,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          hint: const Text('选择或添加一个仓库'),
          items: repoService.repositoryPaths.map((path) {
            return DropdownMenuItem(
              value: path,
              child: Text(path, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (path) {
            if (path != null) {
              repoService.selectRepository(path);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => repoService.addRepository(),
            tooltip: '添加本地仓库',
          ),
          const VerticalDivider(),
          _buildActionButton(Icons.download, '抓取', () => _repoDetailViewKey.currentState?._handleFetch()),
          _buildActionButton(Icons.sync_alt, '拉取', () => _repoDetailViewKey.currentState?._handlePull()),
          _buildActionButton(Icons.upload, '推送', () => _repoDetailViewKey.currentState?._handlePush()),
          const SizedBox(width: 16),
        ],
      ),
      body: selectedRepoPath == null
          ? const Center(child: Text('请通过右上角 "+" 添加一个仓库'))
          : RepositoryDetailView(
        key: _repoDetailViewKey,
        repoPath: selectedRepoPath,
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback? onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(foregroundColor: Colors.grey[300]),
    );
  }
}

class RepositoryDetailView extends StatefulWidget {
  final String repoPath;
  const RepositoryDetailView({super.key, required this.repoPath});

  @override
  State<RepositoryDetailView> createState() => _RepositoryDetailViewState();
}

class _RepositoryDetailViewState extends State<RepositoryDetailView> {
  late GitService _gitService;
  Future<RepoDetailState>? _repoStateFuture;
  GitFileStatus? _selectedFileForDiff;
  Future<String>? _diffFuture;
  bool _isLoadingAction = false;

  @override
  void initState() {
    super.initState();
    _gitService = GitService(repoPath: widget.repoPath);
    _refreshAll();
  }

  void _handleError(dynamic error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('操作失败: $error'), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _refreshAll() {
    setState(() {
      _repoStateFuture = _gitService.getFullRepoState();
      _selectedFileForDiff = null;
      _diffFuture = null;
    });
  }

  Future<void> _runGitAction(Future<void> Function() action, {String? successMessage}) async {
    if (_isLoadingAction) return;
    setState(() => _isLoadingAction = true);
    try {
      await action();
      if (successMessage != null) _showSuccess(successMessage);
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

  Future<void> _handleFetch() async => _runGitAction(() async { await _gitService.fetch(); _refreshAll(); }, successMessage: '抓取成功');
  Future<void> _handlePull() async => _runGitAction(() async { await _gitService.pull(); _refreshAll(); }, successMessage: '拉取成功');
  Future<void> _handlePush() async => _runGitAction(() async { await _gitService.push(); _refreshAll(); }, successMessage: '推送成功');
  Future<void> _handleStageFile(String path) async => _runGitAction(() => _gitService.stageFile(path).then((_) => _refreshAll()));
  Future<void> _handleUnstageFile(String path) async => _runGitAction(() => _gitService.unstageFile(path).then((_) => _refreshAll()));
  Future<void> _handleCommit(String message) async => _runGitAction(() => _gitService.commit(message).then((_) => _refreshAll()), successMessage: '提交成功！');
  Future<void> _handleSwitchBranch(String branchName) async => _runGitAction(() => _gitService.switchBranch(branchName).then((_) => _refreshAll()), successMessage: '已切换到分支 $branchName');
  Future<void> _handleCreateBranch(String branchName) async => _runGitAction(() => _gitService.createBranch(branchName).then((_) => _refreshAll()), successMessage: '已创建并切换到新分支 $branchName');

  void _onFileSelected(GitFileStatus file) {
    setState(() {
      _selectedFileForDiff = file;
      _diffFuture = _gitService.getDiff(file.path, isStaged: file.isStaged);
    });
  }

  // --- 新增处理函数 ---
  void _onCommitSelected(GitCommit commit) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          child: CommitDetailView(
            commit: commit,
            gitService: _gitService,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoDetailState>(
      future: _repoStateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          if (snapshot.error is GitCommandException && (snapshot.error as GitCommandException).message == '这不是一个 Git 仓库。') {
            return NonGitRepositoryView(
              repoPath: widget.repoPath,
              onInit: () => _runGitAction(() => _gitService.initRepository().then((_) => _refreshAll()), successMessage: '仓库初始化成功！'),
            );
          }
          return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('加载仓库失败: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent))));
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('没有数据'));
        }

        final state = snapshot.data!;

        return Row(
          children: [
            Container(
              width: 260,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[900]!))),
              child: BranchListView(
                branches: state.branches,
                onBranchSelected: _handleSwitchBranch,
                onCreateBranch: _handleCreateBranch,
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[900]!))),
                child: CommitHistoryView(
                  commits: state.commits,
                  onCommitSelected: _onCommitSelected, // 传递回调
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: StagingAreaView(
                      allFiles: state.fileStatus,
                      onStage: _handleStageFile,
                      onUnstage: _handleUnstageFile,
                      onFileSelected: _onFileSelected,
                      onCommit: _handleCommit,
                      selectedFile: _selectedFileForDiff,
                    ),
                  ),
                  const Divider(height: 1, color: Colors.black),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: _diffFuture,
                      builder: (context, snapshot) {
                        if (_selectedFileForDiff == null) return const Center(child: Text('选择一个文件以查看差异'));
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError) return Center(child: Text('无法加载差异: ${snapshot.error}'));
                        return DiffView(diffData: snapshot.data ?? '');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class NonGitRepositoryView extends StatelessWidget {
  final String repoPath;
  final VoidCallback onInit;
  const NonGitRepositoryView({super.key, required this.repoPath, required this.onInit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 48, color: Colors.amber),
          const SizedBox(height: 16),
          Text('此目录不是一个 Git 仓库', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(repoPath, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          FilledButton.icon(icon: const Icon(Icons.add), label: const Text('初始化仓库'), onPressed: onInit),
        ],
      ),
    );
  }
}