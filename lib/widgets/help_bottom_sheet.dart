import 'package:flutter/material.dart';

enum HelpTab { travel, equipment, quest, report, template }

class HelpBottomSheet extends StatelessWidget {
  const HelpBottomSheet({super.key, required this.tab});
  final HelpTab tab;

  static void show(BuildContext context, HelpTab tab) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HelpBottomSheet(tab: tab),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _contentFor(tab);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('🔰', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      content.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A3A4A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B8FA0)),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  for (final item in content.items)
                    _HelpItem(item: item),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6CC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      content.closing,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9A7200),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _HelpContent _contentFor(HelpTab tab) {
    switch (tab) {
      case HelpTab.travel:
        return _HelpContent(
          title: '旅行準備の使い方',
          closing: '🤿 次の旅行の準備をしましょう！',
          items: [
            _HelpItem2('カレンダーで旅行日を管理できます', hasImage: true),
            _HelpItem2('日付をタップすると旅行を追加できます', hasImage: false),
            _HelpItem2('旅行ごとに場所・ショップ・スーツ種別・宿泊有無を登録できます', hasImage: false),
            _HelpItem2('テンプレートを選ぶと準備リストが自動生成されます', hasImage: true),
            _HelpItem2('旅行をタップすると準備チェックリストとコスト入力画面に進めます', hasImage: true),
            _HelpItem2('旅行詳細ではダイブ本数・費用を記録でき、レポートでアクティビティ履歴が確認できます', hasImage: false),
            _HelpItem2('テンプレートを使うには、先にテンプレタブで自分用の準備リストをカスタムして保存してください', hasImage: false, isNote: true),
          ],
        );
      case HelpTab.equipment:
        return _HelpContent(
          title: '器材の使い方',
          closing: '🔧 楽しく安全に潜りましょう！',
          items: [
            _HelpItem2('マイ器材を登録して管理できます', hasImage: true),
            _HelpItem2('最終メンテナンスから1年以上、または100本以上でアラートが出ます', hasImage: true),
            _HelpItem2('旅行データと連動してダイブ本数を自動集計します', hasImage: false),
            _HelpItem2('ドライスーツはドライ旅行の本数のみカウントします', hasImage: false),
          ],
        );
      case HelpTab.quest:
        return _HelpContent(
          title: 'クエストの使い方',
          closing: '🐠 次は何を探しにいきますか？',
          items: [
            _HelpItem2('ダイビングで出会った生物にチェックを入れられます', hasImage: true),
            _HelpItem2('出会った場所・時期を記録できます', hasImage: false),
            _HelpItem2('自分だけのオリジナル生物を追加できます', hasImage: false),
          ],
        );
      case HelpTab.report:
        return _HelpContent(
          title: 'レポートの使い方',
          closing: '💙 あなたのダイビングライフを楽しく振り返って、次の計画に役立ててください',
          items: [
            _HelpItem2('これまでの旅行のコストや本数あたりの単価が確認できます', hasImage: true),
            _HelpItem2('グラフで本数やコストの推移を確認できます', hasImage: true),
            _HelpItem2('アクティビティカードでダイビング歴を振り返れます', hasImage: true),
          ],
        );
      case HelpTab.template:
        return _HelpContent(
          title: 'テンプレの使い方',
          closing: '✅ 楽しく潜るためには準備が大事！',
          items: [
            _HelpItem2('旅行の準備の際に活用する準備リストのテンプレートをつくれます', hasImage: true),
            _HelpItem2('用意が必要なものにチェックを入れてください', hasImage: false),
            _HelpItem2('スーツ種別・日帰り宿泊・ボートビーチに応じて推奨項目が変わり、準備を時短できます', hasImage: true),
            _HelpItem2('アイテムをどのカバンに入れるか割り当てられます', hasImage: false),
            _HelpItem2('作成したテンプレートを旅行に適用すると準備リストが自動生成されます', hasImage: true),
          ],
        );
    }
  }
}

class _HelpContent {
  final String title;
  final String closing;
  final List<_HelpItem2> items;
  _HelpContent({required this.title, required this.closing, required this.items});
}

class _HelpItem2 {
  final String text;
  final bool hasImage;
  final bool isNote;
  _HelpItem2(this.text, {required this.hasImage, this.isNote = false});
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({required this.item});
  final _HelpItem2 item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: item.isNote
                      ? const Color(0xFFFF9340)
                      : const Color(0xFF4EC8E8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: item.isNote
                        ? const Color(0xFFC45A00)
                        : const Color(0xFF1A3A4A),
                    fontWeight: item.isNote ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          if (item.hasImage)
            Container(
              margin: const EdgeInsets.only(top: 10, left: 16),
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAFE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8F8FC), width: 1.5),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 32, color: Color(0xFFB0CDD5)),
                    SizedBox(height: 8),
                    Text('スクリーンショット準備中',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB0CDD5))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
