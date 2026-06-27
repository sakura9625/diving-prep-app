import 'package:flutter/material.dart';
import '../services/purchase_service.dart';

class UpgradeDialog {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UpgradeSheet(),
    );
  }
}

class _UpgradeSheet extends StatefulWidget {
  @override
  State<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends State<_UpgradeSheet> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    PurchaseService.initialize().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = PurchaseService.products;
    final travelPack = products.where((p) => p.id == PurchaseService.travelPackId).firstOrNull;
    final lifetime   = products.where((p) => p.id == PurchaseService.lifetimeId).firstOrNull;
    final diveCloud  = products.where((p) => p.id == PurchaseService.diveCloudId).firstOrNull;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('上限に達しました',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
          const SizedBox(height: 8),
          const Text('Travel Packを追加することでもっと記録できます。',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B8FA0))),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (travelPack != null)
              _PlanCard(
                title: 'Travel Pack',
                description: '旅行枠+20件・器材無制限・テンプレ無制限',
                price: travelPack.price,
                color: const Color(0xFF4EC8E8),
                onTap: () async {
                  Navigator.pop(context);
                  await PurchaseService.buy(travelPack);
                },
              ),
            const SizedBox(height: 12),
            if (lifetime != null)
              _PlanCard(
                title: 'Lifetime',
                description: 'すべて無制限・買い切り・永続利用',
                price: lifetime.price,
                color: const Color(0xFFFF9340),
                onTap: () async {
                  Navigator.pop(context);
                  await PurchaseService.buy(lifetime);
                },
              ),
            const SizedBox(height: 12),
            if (diveCloud != null)
              _PlanCard(
                title: 'Dive Cloud',
                description: 'クラウド保存・自動バックアップ・複数端末同期',
                price: '${diveCloud.price}/年',
                color: const Color(0xFFA78BFA),
                onTap: () async {
                  Navigator.pop(context);
                  await PurchaseService.buy(diveCloud);
                },
              ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await PurchaseService.restorePurchases();
                },
                child: const Text('購入を復元する',
                  style: TextStyle(color: Color(0xFF6B8FA0))),
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: Color(0xFF6B8FA0))),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.description,
    required this.price,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String description;
  final String price;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                  const SizedBox(height: 4),
                  Text(description,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B8FA0))),
                ],
              ),
            ),
            Text(price,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
