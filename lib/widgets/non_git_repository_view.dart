import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning,
              size: 64,
              color: Colors.yellow,
            ),
            const SizedBox(height: 16),
            Text(
              '目录 \'$repoPath\' 不是一个 Git 仓库',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onInit,
              child: const Text('初始化 Git 仓库'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: repoPath));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('路径已复制到剪贴板')),
                );
              },
              child: const Text('复制路径'),
            ),
          ],
        ),
      ),
    );
  }
}