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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  for (final item in content.items)
                    _HelpItem(item: item),
                  const SizedBox(height: 16),
                  if (content.limitNote != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E0),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9340).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Color(0xFFC45A00)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              content.limitNote!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFC45A00),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD233),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        content.closing,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A3A4A),
                        ),
                        textAlign: TextAlign.center,
                      ),
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
            _HelpItem2('カレンダーで旅行日を管理できます', hasImage: true, imagePath: 'assets/screenshots/help_travel_calendar.png'),
            _HelpItem2('日付をタップすると旅行を追加できます', hasImage: false),
            _HelpItem2('旅行ごとに場所・ショップ・スーツ種別・宿泊有無を登録できます', hasImage: false),
            _HelpItem2('テンプレートを選ぶと準備リストが自動生成されます', hasImage: true, imagePath: 'assets/screenshots/help_travel_add_dialog.png'),
            _HelpItem2('旅行をタップすると準備チェックリストとコスト入力画面に進めます', hasImage: true, imagePath: 'assets/screenshots/help_travel_cost.png'),
            _HelpItem2('旅行詳細ではダイブ本数・費用を記録でき、レポートでアクティビティ履歴が確認できます', hasImage: false),
            _HelpItem2('テンプレートを使うには、先にテンプレタブで自分用の準備リストをカスタムして保存してください', hasImage: false, isNote: true),
          ],
          limitNote: '今後の旅行は5件まで登録できます。過去の旅行は無制限で登録できます。過去の旅行をできるだけ登録しておくと、アクティビティレポートが楽しめます。登録上限数はTravel Packでさらに追加できます。',
        );
      case HelpTab.equipment:
        return _HelpContent(
          title: '器材の使い方',
          closing: '🔧 楽しく安全に潜りましょう！',
          items: [
            _HelpItem2('マイ器材を登録して管理できます', hasImage: true, imagePath: 'assets/screenshots/help_equipment_list.png'),
            _HelpItem2('最終メンテナンスから1年以上、または100本以上でアラートが出ます', hasImage: true, imagePath: 'assets/screenshots/help_equipment_alert.png'),
            _HelpItem2('旅行データと連動してダイブ本数を自動集計します', hasImage: false),
            _HelpItem2('ドライスーツはドライ旅行の本数のみカウントします', hasImage: false),
          ],
          limitNote: '器材は3件まで登録できます。Travel Packで無制限になります。',
        );
      case HelpTab.quest:
        return _HelpContent(
          title: 'クエストの使い方',
          closing: '🐠 次は何を探しにいきますか？',
          items: [
            _HelpItem2('ダイビングで出会った生物にチェックを入れられます', hasImage: true, imagePath: 'assets/screenshots/help_quest_check.png'),
            _HelpItem2('出会った場所・時期を記録できます', hasImage: false),
            _HelpItem2('自分だけのオリジナル生物を追加できます', hasImage: true, imagePath: 'assets/screenshots/help_quest_custom.png'),
          ],
        );
      case HelpTab.report:
        return _HelpContent(
          title: 'レポートの使い方',
          closing: '💙 あなたのダイビングライフを楽しく振り返って、次の計画に役立ててください',
          items: [
            _HelpItem2('これまでの旅行のコストや本数あたりの単価が確認できます', hasImage: true, imagePath: 'assets/screenshots/help_report_summary.png'),
            _HelpItem2('グラフで本数やコストの推移を確認できます', hasImage: true, imagePath: 'assets/screenshots/help_report_graph.png'),
            _HelpItem2('アクティビティカードでダイビング歴を振り返れます', hasImage: true, imagePath: 'assets/screenshots/help_report_activity1.png'),
            _HelpItem2('', hasImage: true, imagePath: 'assets/screenshots/help_report_activity2.png', noTopMargin: true),
          ],
        );
      case HelpTab.template:
        return _HelpContent(
          title: 'テンプレの使い方',
          closing: '✅ 楽しく潜るためには準備が大事！',
          items: [
            _HelpItem2('旅行の準備の際に活用する準備リストのテンプレートをつくれます', hasImage: true, imagePath: 'assets/screenshots/help_template_list.png'),
            _HelpItem2('用意が必要なものにチェックを入れてください', hasImage: false),
            _HelpItem2('スーツ種別・日帰り宿泊・ボートビーチに応じて推奨項目が変わり、準備を時短できます', hasImage: true, imagePath: 'assets/screenshots/help_template_switch.png'),
            _HelpItem2('アイテムをどのカバンに入れるか割り当てられます', hasImage: false),
            _HelpItem2('作成したテンプレートを旅行に適用すると準備リストが自動生成されます', hasImage: true, imagePath: 'assets/screenshots/help_template_apply.png'),
          ],
          limitNote: 'テンプレートは1件まで保存できます。Travel Packで無制限になります。',
        );
    }
  }
}

class _HelpContent {
  final String title;
  final String closing;
  final List<_HelpItem2> items;
  final String? limitNote;
  _HelpContent({required this.title, required this.closing, required this.items, this.limitNote});
}

class _HelpItem2 {
  final String text;
  final bool hasImage;
  final bool isNote;
  final String? imagePath;
  final bool noTopMargin;
  _HelpItem2(this.text, {required this.hasImage, this.isNote = false, this.imagePath, this.noTopMargin = false});
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
          if (item.text.isNotEmpty)
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
              margin: EdgeInsets.fromLTRB(0, item.noTopMargin ? 0 : 10, 0, 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imagePath != null
                ? Image.asset(
                    item.imagePath!,
                    fit: BoxFit.fitWidth,
                  )
                : Container(
                    height: 160,
                    color: const Color(0xFFF0FAFE),
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
            ),
        ],
      ),
    );
  }
}
