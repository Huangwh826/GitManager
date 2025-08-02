import 'package:flutter/material.dart';
import '../models/git_models.dart';
import 'diff_view.dart';

class CommitFileDiffView extends StatelessWidget {
  final GitFileDiff fileDiff;
  final VoidCallback onClose;

  const CommitFileDiffView({
    super.key,
    required this.fileDiff,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final extension = fileDiff.path.split('.').last;

    return Column(
      children: [
        AppBar(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  fileDiff.path,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '关闭差异视图',
                onPressed: onClose,
              ),
            ],
          ),
          elevation: 0,
          backgroundColor: const Color(0xFF1F2937),
        ),
        const Divider(height: 1),
        Expanded(
          child: DiffView(
            diffData: fileDiff.diffContent,
            fileExtension: extension,
          ),
        ),
      ],
    );
  }
}