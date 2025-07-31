// lib/services/repository_service.dart

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';

// 使用 ChangeNotifier 来通知 UI 刷新
class RepositoryService extends ChangeNotifier {
  // 私有变量，存储仓库路径列表
  final List<String> _repositoryPaths = [];
  String? _selectedRepositoryPath;

  // 公开的 getter，让外部可以安全地访问数据
  List<String> get repositoryPaths => _repositoryPaths;
  String? get selectedRepositoryPath => _selectedRepositoryPath;

  // 构造函数
  RepositoryService() {
    // 在这里我们可以加载上次保存的仓库列表，现在暂时为空
  }

  /// 切换当前选中的仓库
  void selectRepository(String path) {
    if (_repositoryPaths.contains(path) && _selectedRepositoryPath != path) {
      _selectedRepositoryPath = path;
      // 通知所有监听者（UI组件），数据变了，请刷新
      notifyListeners();
    }
  }

  /// 添加一个新的仓库
  Future<void> addRepository() async {
    // 使用 file_picker 库让用户选择一个文件夹
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      if (!_repositoryPaths.contains(selectedDirectory)) {
        _repositoryPaths.add(selectedDirectory);
        // 如果之前没有选中的仓库，则默认选中这个新添加的
        _selectedRepositoryPath ??= selectedDirectory;
        notifyListeners();
      }
    }
  }
}