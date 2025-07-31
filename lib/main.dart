// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  GitFileStatus? _activeDiffFile;
  bool _isLoadingAction = false;
  GitCommit? _selectedCommit;

  MultiSplitViewController? _mainController;
  MultiSplitViewController? _workingCopyController;
  MultiSplitViewController? _commitDetailController;

  bool _controllersInitialized = false;
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
        Area(weight: 0.5, minimalSize: 300),
        Area(weight: 0.5, minimalSize: rightPanelMinWidth),
      ],
    );

    _commitDetailController = MultiSplitViewController(
      areas: [
        Area(weight: 0.6, minimalSize: 300),
        Area(weight: 0.4, minimalSize: 300),
      ],
    );

    _controllersInitialized = true;
  }

  @override
  void dispose() {
    _mainController?.dispose();
    _workingCopyController?.dispose();
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
      _isFirstLayoutDone = false;
      _repoStateFuture = _gitService.getFullRepoState();
      _activeDiffFile = null;
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
        () => _gitService.commit(message).then((_) {
      _refreshAll();
      // 提交后自动关闭差异视图
      setState(() {
        _activeDiffFile = null;
      });
    }),
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
      _activeDiffFile = file;
    });
  }

  void _onCommitSelected(GitCommit commit) {
    setState(() {
      _selectedCommit = commit;
      _activeDiffFile = null; // 查看提交详情时，关闭文件差异视图
    });
  }

  void _onCloseCommitDetail() {
    setState(() => _selectedCommit = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RepoActionsToolbar(
          isLoading: _isLoadingAction,
          onFetch: _handleFetch,
          onPull: _handlePull,
          onPush: _handlePush,
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<RepoDetailState>(
            future: _repoStateFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasData && !_isFirstLayoutDone) {
                _isFirstLayoutDone = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _mainController?.notifyListeners();
                    _workingCopyController?.notifyListeners();
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
          ),
        ),
      ],
    );
  }

  Widget _buildWorkingCopyView(RepoDetailState state) {
    if (_workingCopyController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return MultiSplitView(
      axis: Axis.horizontal,
      controller: _workingCopyController!,
      children: [
        if (_activeDiffFile != null)
          FileDiffView(
            key: ValueKey(_activeDiffFile!.path + _activeDiffFile!.isStaged.toString()),
            gitService: _gitService,
            allFiles: state.fileStatus,
            initialFile: _activeDiffFile!,
            onClose: () {
              setState(() {
                _activeDiffFile = null;
              });
            },
            onFileChanged: (newFile) {
              setState(() {
                _activeDiffFile = newFile;
              });
            },
          )
        else
          CommitHistoryView(
            commits: state.commits,
            onCommitSelected: _onCommitSelected,
          ),
        StagingAreaView(
          allFiles: state.fileStatus,
          onStage: _handleStageFile,
          onUnstage: _handleUnstageFile,
          onFileSelected: _onFileSelectedInWorkingCopy,
          onCommit: _handleCommit,
          selectedFile: _activeDiffFile,
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

/// 一个包含主要 Git 操作按钮的工具栏 Widget。
class RepoActionsToolbar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onFetch;
  final VoidCallback onPull;
  final VoidCallback onPush;

  const RepoActionsToolbar({
    super.key,
    required this.isLoading,
    required this.onFetch,
    required this.onPull,
    required this.onPush,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Theme.of(context).appBarTheme.backgroundColor?.withOpacity(0.5),
      child: Row(
        children: [
          TextButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('抓取'),
            onPressed: isLoading ? null : onFetch,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: const Text('拉取'),
            onPressed: isLoading ? null : onPull,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: const Text('推送'),
            onPressed: isLoading ? null : onPush,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
        ],
      ),
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

// --- 新增 Widget：带键盘导航的文件差异视图 ---
class FileDiffView extends StatefulWidget {
  final GitService gitService;
  final List<GitFileStatus> allFiles;
  final GitFileStatus initialFile;
  final VoidCallback onClose;
  final ValueChanged<GitFileStatus> onFileChanged;

  const FileDiffView({
    super.key,
    required this.gitService,
    required this.allFiles,
    required this.initialFile,
    required this.onClose,
    required this.onFileChanged,
  });

  @override
  State<FileDiffView> createState() => _FileDiffViewState();
}

class _FileDiffViewState extends State<FileDiffView> {
  late GitFileStatus _currentFile;
  late Future<String> _diffFuture;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentFile = widget.initialFile;
    _loadDiff();
    // 请求焦点以便监听键盘事件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _loadDiff() {
    _diffFuture = widget.gitService.getDiff(
      _currentFile.path,
      isStaged: _currentFile.isStaged,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _navigateToFile(-1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _navigateToFile(1);
      }
    }
  }

  void _navigateToFile(int direction) {
    final currentIndex = widget.allFiles.indexWhere((file) =>
    file.path == _currentFile.path && file.isStaged == _currentFile.isStaged);
    if (currentIndex != -1) {
      int nextIndex = currentIndex + direction;
      if (nextIndex >= 0 && nextIndex < widget.allFiles.length) {
        setState(() {
          _currentFile = widget.allFiles[nextIndex];
          _loadDiff();
          widget.onFileChanged(_currentFile);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Column(
        // --- 核心修正：强制拉伸并调整 AppBar 容器 ---
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 自定义 AppBar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            height: 48,
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '变更: ${_currentFile.path}',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '返回提交历史 (Esc)',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 差异内容
          Expanded(
            child: FutureBuilder<String>(
              future: _diffFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('加载差异失败: ${snapshot.error}'),
                    ),
                  );
                }
                return DiffView(diffData: snapshot.data ?? '没有检测到差异。');
              },
            ),
          ),
        ],
      ),
    );
  }
}
