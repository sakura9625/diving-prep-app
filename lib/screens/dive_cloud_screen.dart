import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/apple_auth_service.dart';
import '../services/purchase_service.dart';

class DiveCloudScreen extends StatefulWidget {
  const DiveCloudScreen({super.key});

  @override
  State<DiveCloudScreen> createState() => _DiveCloudScreenState();
}

class _DiveCloudScreenState extends State<DiveCloudScreen> {
  bool _isLoading = false;
  bool _isSignedIn = false;

  @override
  void initState() {
    super.initState();
    _isSignedIn = AppleAuthService.isSignedIn;
    if (!_isSignedIn) {
      PurchaseService.initialize();
    }
  }

  Future<void> _signInAndProceed() async {
    setState(() => _isLoading = true);
    final success = await AppleAuthService.signIn();
    if (!mounted) return;

    if (success) {
      setState(() {
        _isSignedIn = true;
        _isLoading = false;
      });
      await AppleAuthService.migrateData();
      if (!mounted) return;
      _showPurchaseOptions();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('サインインに失敗しました。もう一度お試しください。')),
      );
    }
  }

  void _showPurchaseOptions() {
    final products = PurchaseService.products;
    final diveCloud = products.where((p) => p.id == PurchaseService.diveCloudId).firstOrNull;
    if (diveCloud == null) return;
    PurchaseService.buy(diveCloud);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dive Cloud')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkyCardDiveCloud(),
            const SizedBox(height: 32),
            const Text('Dive Cloudとは',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
            const SizedBox(height: 16),
            _FeatureRow(icon: Icons.cloud_outlined, text: 'クラウド保存・自動バックアップ'),
            _FeatureRow(icon: Icons.phone_iphone, text: '複数端末で同期（iPhone・iPad）'),
            _FeatureRow(icon: Icons.restore, text: '機種変更時もデータを復元'),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6CC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Dive Cloudを使わない場合、端末の初期化や機種変更時にデータが失われる可能性があります。',
                style: TextStyle(fontSize: 13, color: Color(0xFF9A7200)),
              ),
            ),
            const SizedBox(height: 32),
            if (_isSignedIn) ...[
              const Text('サインイン済みです',
                style: TextStyle(fontSize: 14, color: Color(0xFF4EC8E8))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _showPurchaseOptions,
                  child: const Text('Dive Cloudを購入する'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SignInWithAppleButton(
                      onPressed: _signInAndProceed,
                    ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Appleでサインインして購入へ進む',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B8FA0)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFA78BFA).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFFA78BFA)),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15, color: Color(0xFF1A3A4A))),
        ],
      ),
    );
  }
}

class SkyCardDiveCloud extends StatelessWidget {
  const SkyCardDiveCloud({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFA78BFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('☁️', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text('Dive Cloud',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          SizedBox(height: 4),
          Text('年額 ¥2,000',
            style: TextStyle(fontSize: 16, color: Colors.white70)),
        ],
      ),
    );
  }
}
