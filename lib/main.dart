// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'services/repository_service.dart';
import 'services/git_service.dart';
import 'models/git_models.dart';
import 'widgets/branch_list_view.dart';
import 'widgets/diff_view.dart';
import 'widgets/commit_history_view.dart';
import 'widgets/staging_area_view.dart';
import 'widgets/commit_detail_view.dart';
import 'widgets/window_title_bar.dart';

// --- 新增导入 ---
import 'widgets/remote_repository_view.dart';
import 'widgets/stash_management_view.dart';
import 'widgets/conflict_resolver_view.dart';
import 'widgets/file_diff_view.dart';
import 'widgets/commit_file_diff_view.dart';
import 'widgets/non_git_repository_view.dart';


void main() {
  // 确保Flutter绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化bitsdojo_window
  doWhenWindowReady(() {
    const initialSize = Size(1280, 720);
    appWindow.minSize = const Size(800, 600);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = 'GitManager';
    appWindow.show();
  });

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

  /// 关闭指定索引的仓库
  void _closeRepository(int index, RepositoryService repoService) {
    if (index < 0 || index >= repoService.repositoryPaths.length) return;

    final removedPath = repoService.repositoryPaths[index];
    repoService.removeRepository(removedPath);
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
      appBar: WindowTitleBar(
        tabController: _tabController,
        repositoryPaths: repos,
        onAddRepository: () => repoService.addRepository(),
        onCloseRepository: (index) => _closeRepository(index, repoService),
      ),
      body: repos.isEmpty
          ? const Center(child: Text('请通过右上角 "+" 添加一个仓库'))
          : (isControllerReady
          ? TabBarView(
        controller: _tabController!,
        children: repos
            .map((path) => RepositoryDetailView(key: ValueKey(path), repoPath: path)) // 使用 ValueKey 保证重建
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

  GitFileDiff? _selectedCommitFileDiff;

  MultiSplitViewController? _mainController;
  MultiSplitViewController? _workingCopyController;
  MultiSplitViewController? _commitDetailController;

  bool _controllersInitialized = false;
  bool _isFirstLayoutDone = false;
  late MediaQueryData _mediaQuery;

  // --- 新增状态：用于跟踪冲突文件 ---
  List<String> _conflictFiles = [];

  @override
  void initState() {
    super.initState();
    _gitService = GitService(repoPath: widget.repoPath);
    _mediaQuery = MediaQueryData(); // 初始化为空，会在didChangeDependencies中更新
    _refreshAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newMediaQuery = MediaQuery.of(context);
    if (_mediaQuery.size != newMediaQuery.size) {
      _mediaQuery = newMediaQuery;
      _updateControllersForNewSize(_mediaQuery.size);
    }
    if (!_controllersInitialized) {
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    if (!mounted) return;

    // 创建控制器实例
    _mainController = MultiSplitViewController();
    _workingCopyController = MultiSplitViewController();
    _commitDetailController = MultiSplitViewController();

    _mediaQuery = MediaQuery.of(context);
    final screenSize = _mediaQuery.size;
    _updateControllersForNewSize(screenSize);

    _controllersInitialized = true;
  }

  void _updateControllersForNewSize(Size newSize) {
    if (!mounted) return;

    // 根据新尺寸重新计算面板大小
    final leftPanelWidth = (newSize.width * 0.2).clamp(200.0, 300.0);
    final rightPanelMinWidth = (newSize.width * 0.3).clamp(350.0, 500.0);

    // 更新主控制器
    if (_mainController != null) {
      _mainController!.areas = [
        Area(size: leftPanelWidth, minimalSize: 200),
        Area(minimalSize: rightPanelMinWidth),
      ];
    }

    // 更新工作区控制器
    if (_workingCopyController != null) {
      _workingCopyController!.areas = [
        Area(weight: 0.5, minimalSize: 300),
        Area(weight: 0.5, minimalSize: rightPanelMinWidth),
      ];
    }

    // 更新提交详情控制器
    if (_commitDetailController != null) {
      _commitDetailController!.areas = [
        Area(weight: 0.5, minimalSize: 300), // 提交历史
        Area(weight: 0.5, minimalSize: rightPanelMinWidth),  // 提交详情
      ];
    }
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
      // 在获取仓库状态的同时，检查冲突文件
      _repoStateFuture = _gitService.getFullRepoState();
      _gitService.getConflictFiles().then((files) {
        if(mounted) setState(() => _conflictFiles = files);
      });
      _activeDiffFile = null;
      _selectedCommit = null;
      _selectedCommitFileDiff = null;
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

  // --- 核心优化：修改暂存和取消暂存的逻辑 ---
  Future<void> _handleStageFile(String path) async => _runGitAction(
        () => _gitService.stageFile(path).then((_) {
          _updateFileStatus(); // 调用局部刷新
        }),
  );

  Future<void> _handleUnstageFile(String path) async => _runGitAction(
        () => _gitService.unstageFile(path).then((_) {
          _updateFileStatus(); // 调用局部刷新
        }),
  );

  // --- 核心优化：新增的局部刷新方法 ---
  Future<void> _updateFileStatus() async {
    try {
      final currentState = await _repoStateFuture;
      if (currentState == null || !mounted) return;

      // 只获取最新的文件状态
      final newFileStatus = await _gitService.getStatus();

      // 使用旧的分支和提交数据，结合新的文件状态，更新Future
      setState(() {
        _repoStateFuture = Future.value(RepoDetailState(
          branches: currentState.branches,
          commits: currentState.commits,
          fileStatus: newFileStatus,
        ));
      });
    } catch (e) {
      _handleError(e);
    }
  }
  
  Future<void> _handleCommit(String message) async => _runGitAction(
        () => _gitService.commit(message).then((_) {
      _refreshAll();
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
  
  // --- 新增 Cherry-pick 处理函数 ---
  Future<void> _handleCherryPick(GitCommit commit) async {
    // 弹出一个确认对话框
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认 Cherry-pick'),
        content: Text('您确定要 cherry-pick 这个提交吗？\n\n${commit.shortHash} - ${commit.message.split('\n').first}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('确认')),
        ],
      ),
    );

    if (confirm == true) {
      await _runGitAction(
            () => _gitService.cherryPick(commit.hash).then((_) => _refreshAll()),
        successMessage: '已 cherry-pick 提交: ${commit.shortHash}',
      );
    }
  }


  void _onFileSelectedInWorkingCopy(GitFileStatus file) {
    setState(() {
      _activeDiffFile = file;
    });
  }

  void _onCommitSelected(GitCommit commit) {
    setState(() {
      if (_selectedCommit?.hash != commit.hash) {
        _selectedCommitFileDiff = null;
      }
      _selectedCommit = commit;
      _activeDiffFile = null;
    });
  }

  void _onCloseCommitDetail() {
    setState(() {
      _selectedCommit = null;
      _selectedCommitFileDiff = null;
    });
  }

  void _onCommitFileSelected(GitFileDiff file) {
    setState(() {
      _selectedCommitFileDiff = file;
    });
  }
  
  // --- 新增：导航到新页面的方法 ---
  void _navigateToRemoteManagement() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemoteRepositoryView()));
  }

  void _navigateToStashManagement() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StashManagementView()));
  }

  void _navigateToConflictResolver() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConflictResolverView()))
        .then((_) => _refreshAll()); // 解决冲突后刷新状态
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- 核心修改：将导航函数和冲突状态传递给工具栏 ---
        RepoActionsToolbar(
          isLoading: _isLoadingAction,
          onFetch: _handleFetch,
          onPull: _handlePull,
          onPush: _handlePush,
          onNavigateToRemotes: _navigateToRemoteManagement,
          onNavigateToStashes: _navigateToStashManagement,
          onNavigateToConflictResolver: _navigateToConflictResolver,
          hasConflicts: _conflictFiles.isNotEmpty,
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<RepoDetailState>(
            future: _repoStateFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !_isFirstLayoutDone) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                if (snapshot.error is GitCommandException &&
                    (snapshot.error as GitCommandException).message.contains('这不是一个 Git 仓库')) {
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
              
              if (snapshot.hasData && !_isFirstLayoutDone) {
                _isFirstLayoutDone = true;
              }

              final state = snapshot.data!;

              if (!_controllersInitialized || _mainController == null) {
                return const Center(child: CircularProgressIndicator());
              }

              return LayoutBuilder(
            builder: (context, constraints) {
              if (_controllersInitialized && constraints.maxWidth > 0) {
                final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
                if (_mediaQuery.size != currentSize) {
                  _mediaQuery = MediaQuery.of(context);
                  _updateControllersForNewSize(currentSize);
                }
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
            onCherryPick: _handleCherryPick,
          ),
        StagingAreaView(
          allFiles: state.fileStatus,
          onStage: _handleStageFile,
          onUnstage: _handleUnstageFile,
          onFileSelected: _onFileSelectedInWorkingCopy,
          onCommit: _handleCommit,
          selectedFile: _activeDiffFile,
          onRefreshFileStatus: _updateFileStatus,
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
        IndexedStack(
          index: _selectedCommitFileDiff != null ? 1 : 0,
          children: [
            CommitHistoryView(
              commits: state.commits,
              onCommitSelected: _onCommitSelected,
              selectedCommit: commit,
              onCherryPick: _handleCherryPick,
            ),
            if (_selectedCommitFileDiff != null)
              CommitFileDiffView(
                key: ValueKey(_selectedCommitFileDiff!.path),
                fileDiff: _selectedCommitFileDiff!,
                onClose: () {
                  setState(() {
                    _selectedCommitFileDiff = null;
                  });
                },
              ),
          ],
        ),
        CommitDetailView(
          key: ValueKey(commit.hash),
          commit: commit,
          gitService: _gitService,
          onClose: _onCloseCommitDetail,
          selectedFile: _selectedCommitFileDiff,
          onFileSelected: _onCommitFileSelected,
        ),
      ],
    );
  }
}

// --- 核心修改：扩展工具栏以包含新功能 ---
class RepoActionsToolbar extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onFetch;
  final VoidCallback onPull;
  final VoidCallback onPush;
  final VoidCallback onNavigateToRemotes;
  final VoidCallback onNavigateToStashes;
  final VoidCallback onNavigateToConflictResolver;
  final bool hasConflicts;

  const RepoActionsToolbar({
    super.key,
    required this.isLoading,
    required this.onFetch,
    required this.onPull,
    required this.onPush,
    required this.onNavigateToRemotes,
    required this.onNavigateToStashes,
    required this.onNavigateToConflictResolver,
    required this.hasConflicts,
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
            label: const Text('抓取（Fetch）'),
            onPressed: isLoading ? null : onFetch,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.arrow_downward, size: 16),
            label: const Text('拉取（Pull）'),
            onPressed: isLoading ? null : onPull,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.arrow_upward, size: 16),
            label: const Text('推送（Push）'),
            onPressed: isLoading ? null : onPush,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          const VerticalDivider(width: 24),
          // --- 新增按钮 ---
          TextButton.icon(
            icon: const Icon(Icons.public, size: 16),
            label: const Text('远程（Remote）'),
            onPressed: isLoading ? null : onNavigateToRemotes,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.inventory_2_outlined, size: 16),
            label: const Text('储藏（Stash）'),
            onPressed: isLoading ? null : onNavigateToStashes,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.grey,
            ),
          ),
          const Spacer(), // 将冲突按钮推到右侧
          // --- 条件显示的冲突解决按钮 ---
          if (hasConflicts)
            FilledButton.icon(
              icon: const Icon(Icons.warning_amber, size: 16),
              label: const Text('解决冲突'),
              onPressed: isLoading ? null : onNavigateToConflictResolver,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
            ),
        ],
      ),
    );
  }
}

// (其他辅助 Widget 保持不变)
// ... NonGitRepositoryView, FileDiffView, CommitFileDiffView ...