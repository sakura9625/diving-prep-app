import 'package:flutter/material.dart';

class UpgradeDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('上限に達しました'),
        content: const Text('Travel Packを追加することでもっと記録できます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 将来：課金画面へ遷移
            },
            child: const Text('Travel Packを見る'),
          ),
        ],
      ),
    );
  }
}
