// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:multi_split_view/multi_split_view.dart';
import 'services/repository_service.dart';
import 'services/git_service.dart';
import 'models/git_models.dart';
import 'widgets/commit_view.dart';
import 'widgets/branch_list_view.dart';
import 'widgets/diff_view.dart';
import 'widgets/commit_history_view.dart';
import 'widgets/staging_area_view.dart';
import 'widgets/commit_detail_view.dart';

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
        tabBarTheme: TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: Colors.blueAccent, width: 2),
          ),
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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  bool _isUpdatingTabs = false;
  List<String> _lastReposList = [];

  @override
  void initState() {
    super.initState();
    final repoService = Provider.of<RepositoryService>(context, listen: false);
    _lastReposList = List.from(repoService.repositoryPaths);
    repoService.addListener(_onRepoServiceChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeTabController();
      }
    });
  }

  @override
  void dispose() {
    final repoService = Provider.of<RepositoryService>(context, listen: false);
    repoService.removeListener(_onRepoServiceChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _initializeTabController() {
    final repoService = Provider.of<RepositoryService>(context, listen: false);
    final repos = repoService.repositoryPaths;

    if (repos.isNotEmpty) {
      _tabController = TabController(length: repos.length, vsync: this);
      _addTabControllerListener();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _addTabControllerListener() {
    _tabController?.addListener(() {
      if (_isUpdatingTabs || !mounted) return;

      final repoService = Provider.of<RepositoryService>(context, listen: false);
      if (!_tabController!.indexIsChanging &&
          _tabController!.index < repoService.repositoryPaths.length) {
        final selectedPath = repoService.repositoryPaths[_tabController!.index];
        if (repoService.selectedRepositoryPath != selectedPath) {
          repoService.selectRepository(selectedPath);
        }
      }
    });
  }

  void _onRepoServiceChanged() {
    if (_isUpdatingTabs || !mounted) return;

    final repoService = Provider.of<RepositoryService>(context, listen: false);
    final currentRepos = repoService.repositoryPaths;

    if (_listEquals(currentRepos, _lastReposList)) {
      final selectedPath = repoService.selectedRepositoryPath;
      if (selectedPath != null && _tabController != null) {
        final newIndex = currentRepos.indexOf(selectedPath);
        if (newIndex != -1 && newIndex != _tabController!.index) {
          _tabController!.animateTo(newIndex);
        }
      }
      return;
    }

    _isUpdatingTabs = true;
    _lastReposList = List.from(currentRepos);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isUpdatingTabs = false;
        return;
      }

      try {
        _updateTabController(currentRepos);
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('更新 TabController 时出错: $e');
      } finally {
        _isUpdatingTabs = false;
      }
    });
  }

  bool _listEquals(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  void _updateTabController(List<String> repos) {
    _tabController?.dispose();
    _tabController = null;

    if (repos.isNotEmpty) {
      final repoService = Provider.of<RepositoryService>(context, listen: false);
      final selectedPath = repoService.selectedRepositoryPath;
      int initialIndex = selectedPath != null ? repos.indexOf(selectedPath) : 0;
      if (initialIndex == -1) initialIndex = 0;

      _tabController = TabController(
        length: repos.length,
        vsync: this,
        initialIndex: initialIndex,
      );
      _addTabControllerListener();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repoService = context.watch<RepositoryService>();
    final repos = repoService.repositoryPaths;

    final bool isControllerReady = _tabController != null && _tabController!.length == repos.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: (repos.isNotEmpty && isControllerReady)
                  ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: repos
                    .map((path) => Tab(
                  text: path.split(Platform.pathSeparator).last,
                ))
                    .toList(),
              )
                  : (repos.isEmpty
                  ? const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('GitManager'),
              )
                  : const SizedBox()),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => repoService.addRepository(),
              tooltip: '添加本地仓库',
            ),
          ],
        ),
      ),
      body: repos.isEmpty
          ? const Center(child: Text('请通过右上角 "+" 添加一个仓库'))
          : (isControllerReady
          ? TabBarView(
        controller: _tabController!,
        children: repos
            .map((path) => RepositoryDetailView(repoPath: path))
            .toList(),
      )
          : const Center(child: CircularProgressIndicator())),
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
  GitCommit? _selectedCommit;

  MultiSplitViewController? _mainController;
  MultiSplitViewController? _workingCopyController;
  MultiSplitViewController? _stagingController;
  MultiSplitViewController? _commitDetailController;

  bool _controllersInitialized = false;
  // --- 新增状态标记 ---
  bool _isFirstLayoutDone = false;

  @override
  void initState() {
    super.initState();
    _gitService = GitService(repoPath: widget.repoPath);
    _refreshAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersInitialized) {
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final leftPanelWidth = (screenWidth * 0.2).clamp(200.0, 300.0);
    final rightPanelMinWidth = (screenWidth * 0.3).clamp(350.0, 500.0);

    _mainController = MultiSplitViewController(
      areas: [
        Area(size: leftPanelWidth, minimalSize: 200),
        Area(minimalSize: rightPanelMinWidth),
      ],
    );

    _workingCopyController = MultiSplitViewController(
      areas: [
        Area(weight: 0.6, minimalSize: 300),
        Area(weight: 0.4, minimalSize: rightPanelMinWidth),
      ],
    );

    _stagingController = MultiSplitViewController(
      areas: [
        Area(weight: 0.5, minimalSize: 300),
        Area(weight: 0.5, minimalSize: 300),
      ],
    );

    _commitDetailController = MultiSplitViewController(
      areas: [
        Area(weight: 0.6, minimalSize: 300),
        Area(weight: 0.4, minimalSize: 300),
      ],
    );

    _controllersInitialized = true;

    // --- 移除此处的刷新逻辑，因为它执行得太早 ---
    // WidgetsBinding.instance.addPostFrameCallback((_) { ... });
  }

  @override
  void dispose() {
    _mainController?.dispose();
    _workingCopyController?.dispose();
    _stagingController?.dispose();
    _commitDetailController?.dispose();
    super.dispose();
  }

  void _handleError(dynamic error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('操作失败: $error'),
        backgroundColor: Colors.redAccent,
      ),
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
      // --- 核心修正：重置布局完成标记 ---
      _isFirstLayoutDone = false;
      _repoStateFuture = _gitService.getFullRepoState();
      _selectedFileForDiff = null;
      _diffFuture = null;
      _selectedCommit = null;
    });
  }

  Future<void> _runGitAction(
      Future<void> Function() action, {
        String? successMessage,
      }) async {
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

  Future<void> _handleFetch() async => _runGitAction(() async {
    await _gitService.fetch();
    _refreshAll();
  }, successMessage: '抓取成功');

  Future<void> _handlePull() async => _runGitAction(() async {
    await _gitService.pull();
    _refreshAll();
  }, successMessage: '拉取成功');

  Future<void> _handlePush() async => _runGitAction(() async {
    await _gitService.push();
    _refreshAll();
  }, successMessage: '推送成功');

  Future<void> _handleStageFile(String path) async => _runGitAction(
        () => _gitService.stageFile(path).then((_) => _refreshAll()),
  );

  Future<void> _handleUnstageFile(String path) async => _runGitAction(
        () => _gitService.unstageFile(path).then((_) => _refreshAll()),
  );

  Future<void> _handleCommit(String message) async => _runGitAction(
        () => _gitService.commit(message).then((_) => _refreshAll()),
    successMessage: '提交成功！',
  );

  Future<void> _handleSwitchBranch(String branchName) async => _runGitAction(
        () => _gitService.switchBranch(branchName).then((_) => _refreshAll()),
    successMessage: '已切换到分支 $branchName',
  );

  Future<void> _handleCreateBranch(String branchName) async => _runGitAction(
        () => _gitService.createBranch(branchName).then((_) => _refreshAll()),
    successMessage: '已创建并切换到新分支 $branchName',
  );

  void _onFileSelectedInWorkingCopy(GitFileStatus file) {
    setState(() {
      _selectedFileForDiff = file;
      _diffFuture = _gitService.getDiff(file.path, isStaged: file.isStaged);
    });
  }

  void _onCommitSelected(GitCommit commit) {
    setState(() => _selectedCommit = commit);
  }

  void _onCloseCommitDetail() {
    setState(() => _selectedCommit = null);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RepoDetailState>(
      future: _repoStateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // --- 核心修正：在组件真实构建后触发布局刷新 ---
        if (snapshot.hasData && !_isFirstLayoutDone) {
          _isFirstLayoutDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mainController?.notifyListeners();
              _workingCopyController?.notifyListeners();
              _stagingController?.notifyListeners();
              _commitDetailController?.notifyListeners();
            }
          });
        }

        if (snapshot.hasError) {
          if (snapshot.error is GitCommandException &&
              (snapshot.error as GitCommandException).message == '这不是一个 Git 仓库。') {
            return NonGitRepositoryView(
              repoPath: widget.repoPath,
              onInit: () => _runGitAction(
                    () => _gitService.initRepository().then((_) => _refreshAll()),
                successMessage: '仓库初始化成功！',
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '加载仓库失败: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const Center(child: Text('没有数据'));

        final state = snapshot.data!;

        if (!_controllersInitialized || _mainController == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return MultiSplitView(
          controller: _mainController!,
          children: [
            BranchListView(
              branches: state.branches,
              onBranchSelected: _handleSwitchBranch,
              onCreateBranch: _handleCreateBranch,
            ),
            if (_selectedCommit == null)
              _buildWorkingCopyView(state)
            else
              _buildCommitDetailView(state, _selectedCommit!),
          ],
        );
      },
    );
  }

  Widget _buildWorkingCopyView(RepoDetailState state) {
    if (_workingCopyController == null || _stagingController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MultiSplitView(
      axis: Axis.horizontal,
      controller: _workingCopyController!,
      children: [
        CommitHistoryView(
          commits: state.commits,
          onCommitSelected: _onCommitSelected,
        ),
        MultiSplitView(
          axis: Axis.vertical,
          controller: _stagingController!,
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: StagingAreaView(
                allFiles: state.fileStatus,
                onStage: _handleStageFile,
                onUnstage: _handleUnstageFile,
                onFileSelected: _onFileSelectedInWorkingCopy,
                onCommit: _handleCommit,
                selectedFile: _selectedFileForDiff,
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
              ),
              child: FutureBuilder<String>(
                future: _diffFuture,
                builder: (context, diffSnapshot) {
                  if (_selectedFileForDiff == null) {
                    return const Center(
                      child: Text('选择一个文件以查看差异'),
                    );
                  }
                  if (diffSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (diffSnapshot.hasError) {
                    return Center(
                      child: Text('加载差异失败: ${diffSnapshot.error}'),
                    );
                  }
                  return DiffView(
                    diffData: diffSnapshot.data ?? '',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommitDetailView(RepoDetailState state, GitCommit commit) {
    if (_commitDetailController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MultiSplitView(
      axis: Axis.horizontal,
      controller: _commitDetailController!,
      children: [
        CommitHistoryView(
          commits: state.commits,
          onCommitSelected: _onCommitSelected,
          selectedCommit: commit,
        ),
        CommitDetailView(
          commit: commit,
          gitService: _gitService,
          onClose: _onCloseCommitDetail,
        ),
      ],
    );
  }
}

class NonGitRepositoryView extends StatelessWidget {
  final String repoPath;
  final VoidCallback onInit;

  const NonGitRepositoryView({
    super.key,
    required this.repoPath,
    required this.onInit,
  });

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
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('初始化仓库'),
            onPressed: onInit,
          ),
        ],
      ),
    );
  }
}