# Claude Code 実装指示書
## ダイビング準備アプリ — デザインリニューアル

添付の `design-regulation.md` を必ず参照した上で実装してください。
既存コードのカラーコードはすべてレギュレーションの値に置き換えてください。

---

## 0. 事前準備

### パッケージ追加
```yaml
# pubspec.yaml
dependencies:
  phosphor_flutter: ^2.1.0
```

### ThemeData の更新
`main.dart` の `ThemeData` を以下に置き換えてください。

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: Color(0xFF4EC8E8),
    primary: Color(0xFF4EC8E8),
    onPrimary: Colors.white,
    secondary: Color(0xFFFF9340),
    onSecondary: Colors.white,
    surface: Colors.white,
    background: Color(0xFFF9FEFF),
  ),
  scaffoldBackgroundColor: Color(0xFFF9FEFF),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF1A3A4A),
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: Color(0xFF1A3A4A),
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  ),
  cardTheme: CardTheme(
    color: Colors.white,
    elevation: 2,
    shadowColor: Colors.black12,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Color(0xFF4EC8E8),
    unselectedItemColor: Color(0xFFB0CDD5),
    elevation: 0,
  ),
)
```

### Material Icons → Phosphor Icons の置き換え
既存の `Icons.*` をすべて以下に差し替えてください。

| 旧（Icons.*） | 新（PhosphorIcons） |
|---|---|
| `Icons.travel_explore` | `PhosphorIcons.airplane()` |
| `Icons.scuba_diving` | `PhosphorIcons.scubaMask()` |
| `Icons.bubble_chart` | `PhosphorIcons.fish()` |
| `Icons.bar_chart` | `PhosphorIcons.chartBar()` |
| `Icons.checklist` | `PhosphorIcons.listChecks()` |
| `Icons.place` / `Icons.location_on` | `PhosphorIcons.mapPin()` |
| `Icons.calendar_today` | `PhosphorIcons.calendarBlank()` |
| `Icons.add` | `PhosphorIcons.plus()` |
| `Icons.edit` / `Icons.edit_outlined` | `PhosphorIcons.pencilSimple()` |
| `Icons.delete` / `Icons.delete_outline` | `PhosphorIcons.trash()` |
| `Icons.warning_amber_rounded` | `PhosphorIcons.warning()` |
| `Icons.check_circle` | `PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)` |
| `Icons.more_vert` | `PhosphorIcons.dotsThreeVertical()` |
| `Icons.copy` | `PhosphorIcons.copy()` |
| `Icons.build` / `Icons.build_outlined` | `PhosphorIcons.wrench()` |

- BottomNavigationBar のアクティブアイコンのみ `PhosphorIconsStyle.fill` を使用
- その他すべて style 指定なし（regular / アウトライン）

---

## 1. BottomNavigationBar（全画面共通）

- 背景色: `Colors.white`
- 上ボーダー: `Border(top: BorderSide(color: Color(0xFFE8F8FC), width: 1.5))`
- 選択色: `Color(0xFF4EC8E8)`
- 非選択色: `Color(0xFFB0CDD5)`
- アクティブアイテムの下に直径4pxのドットインジケーターを追加

```dart
// アクティブドットの実装例
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    PhosphorIcon(
      isActive
        ? PhosphorIcons.airplane(PhosphorIconsStyle.fill)
        : PhosphorIcons.airplane(),
      color: isActive ? Color(0xFF4EC8E8) : Color(0xFFB0CDD5),
      size: 24,
    ),
    if (isActive)
      Container(
        margin: EdgeInsets.only(top: 3),
        width: 4, height: 4,
        decoration: BoxDecoration(
          color: Color(0xFF4EC8E8),
          shape: BoxShape.circle,
        ),
      ),
  ],
)
```

---

## 2. SkyCard ウィジェット（全画面共通）

各画面の上部（AppBar直下）に共通で使用するカードを新規ウィジェットとして作成してください。

**ファイル**: `lib/widgets/sky_card.dart`

```dart
// プロパティ
final String title;      // メインテキスト（例：「今日の予定」「マイ器材」）
final String subtitle;   // サブテキスト（例：日付・件数など）
final String? emoji;     // 右上絵文字（任意）
```

- 背景色: `Color(0xFF4EC8E8)`
- 角丸: `BorderRadius.circular(16)`
- 余白: `margin: EdgeInsets.fromLTRB(16, 8, 16, 12)`
- 装飾（右上）: 白半透明の雲シェイプ（`Colors.white.withOpacity(0.4)`）
- 装飾（右下）: 太陽サークル（`Color(0xFFFFD233)`、直径28px）
- テキスト色: すべて `Colors.white`
- subtitle: `fontSize: 11, color: Colors.white.withOpacity(0.85)`
- title: `fontSize: 15, fontWeight: FontWeight.w700`

---

## 3. TravelScreen（旅行準備）

### 3-1. SkyCard
- title: `「${旅行件数}件の旅行予定」`
- subtitle: 今月の日付範囲 または「旅行を追加しましょう」

### 3-2. カレンダー（TableCalendar）
- 旅行がある日付のマーカー色: `Color(0xFF4EC8E8)`
- 選択日の塗りつぶし: `Color(0xFF4EC8E8)`
- 今日の日付ボーダー: `Color(0xFF4EC8E8)`、塗りなし

### 3-3. 「旅行を追加」ボタン
- `FilledButton`
- 背景色: `Color(0xFFFF9340)`（Sunset Orange）
- 角丸: `BorderRadius.circular(12)`
- 左アイコン: `PhosphorIcons.plus()`

### 3-4. 旅行カード
- 左端カラーバー: 幅5px、`Color(0xFF4EC8E8)`
- 角丸: `BorderRadius.circular(12)`
- タイトル: `fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A)`
- サブテキスト（日付・場所）: `fontSize: 12, color: Color(0xFF6B8FA0)`
- ステータスチップ（`BorderRadius.circular(20)` のピル形）:
  - ウェット: 背景 `Color(0xFFE6F8FC)` / 文字 `Color(0xFF1A7A94)`
  - ドライ: 背景 `Color(0xFFF1EEFF)` / 文字 `Color(0xFF6D43D4)`
  - 日帰り: 背景 `Color(0xFFEEFACC)` / 文字 `Color(0xFF5A8A00)`
  - 宿泊: 背景 `Color(0xFFFFF0E0)` / 文字 `Color(0xFFC45A00)`
- 右上メニュー: `PhosphorIcons.dotsThreeVertical()`

---

## 4. TripDetailScreen（準備リスト）

### 4-1. SkyCard
- title: 旅行名（例：「鈴木ブラザーズ 🤿」）
- subtitle: `「${日付}・${場所}」`

### 4-2. 進捗バー
現在の細線バーを以下に変更してください。

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          PhosphorIcon(PhosphorIcons.checkCircle(), size: 14, color: Color(0xFF4EC8E8)),
          SizedBox(width: 4),
          Text('準備状況', style: TextStyle(fontSize: 11, color: Color(0xFF4EC8E8), fontWeight: FontWeight.w600)),
        ]),
        Text('$checkedCount / $totalCount 項目',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
      ],
    ),
    SizedBox(height: 6),
    ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 8,
        backgroundColor: Color(0xFFE8F8FC),
        // 100%達成時は Color(0xFFFFD233)（Sun Yellow）に変化
        valueColor: AlwaysStoppedAnimation(
          progress >= 1.0 ? Color(0xFFFFD233) : Color(0xFF4EC8E8),
        ),
      ),
    ),
  ],
)
```

### 4-3. カテゴリ見出し
カテゴリ名の左にカラードット＋アイコンを追加してください。

```dart
// カテゴリ別アイコンの対応表
// 重要     → PhosphorIcons.warning()          色: Color(0xFFFF5B5B)
// 服装     → PhosphorIcons.hanger()           色: Color(0xFFFF9340)
// 器材     → PhosphorIcons.scubaMask()        色: Color(0xFF4EC8E8)
// 書類     → PhosphorIcons.filePdf()          色: Color(0xFFA78BFA)
// 衛生用品 → PhosphorIcons.firstAid()         色: Color(0xFF7BBF00)
// 未設定   → PhosphorIcons.question()         色: Color(0xFF6B8FA0)
```

- カテゴリドット: 直径8px、各カテゴリ色
- アイコン: `size: 14`、各カテゴリ色
- カテゴリ名: `fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A)`
- 件数: `fontSize: 10, color: Color(0xFF6B8FA0)`

### 4-4. タスクカード（チェックリスト項目）
現在のリスト行をカード形式に変更してください。

```dart
Container(
  margin: EdgeInsets.only(bottom: 5),
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Color(0xFFE8F8FC), width: 1.5),
  ),
  child: Row(children: [
    // チェックサークル
    GestureDetector(
      onTap: () => toggleCheck(item),
      child: Container(
        width: 16, height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: item.isChecked ? Color(0xFF4EC8E8) : Colors.transparent,
          border: Border.all(
            color: item.isChecked ? Color(0xFF4EC8E8) : Color(0xFFB0CDD5),
            width: 1.5,
          ),
        ),
        child: item.isChecked
          ? PhosphorIcon(PhosphorIcons.check(), size: 10, color: Colors.white)
          : null,
      ),
    ),
    SizedBox(width: 8),
    Expanded(
      child: Text(item.name,
        style: TextStyle(fontSize: 12, color: Color(0xFF1A3A4A))),
    ),
    PhosphorIcon(PhosphorIcons.copy(), size: 14, color: Color(0xFFB0CDD5)),
  ]),
)
```

### 4-5. フィルターチップ
- 「すべて」: 背景 `Color(0xFF4EC8E8)`、文字 `Colors.white`
- その他: 背景 `Color(0xFFF0FAFE)`、文字 `Color(0xFF4EC8E8)`、ボーダー `Color(0xFFE8F8FC)`
- 角丸: `BorderRadius.circular(20)`
- フォント: `fontSize: 10, fontWeight: FontWeight.w600`

---

## 5. EquipmentScreen（マイ器材）

### 5-1. SkyCard
- title: `「マイ器材 ${件数}点」`
- subtitle: アラートがある場合「⚠ ${n}点のメンテナンスを確認してください」

### 5-2. 「器材を追加」ボタン
- `OutlinedButton`
- ボーダー・文字色: `Color(0xFF4EC8E8)`
- 角丸: `BorderRadius.circular(12)`
- 左アイコン: `PhosphorIcons.plus()`

### 5-3. 器材タイプバッジ
既存の色を以下に統一し、形状を `BorderRadius.circular(20)` のピル形に変更してください。

| 器材タイプ | 背景色 | 文字色 |
|---|---|---|
| BCD | `Color(0xFFE6F8FC)` | `Color(0xFF1A7A94)` |
| レギュレーター | `Color(0xFFEEFACC)` | `Color(0xFF5A8A00)` |
| ドライスーツ | `Color(0xFFF1EEFF)` | `Color(0xFF6D43D4)` |
| ウェットスーツ | `Color(0xFFE6F8FC)` | `Color(0xFF1A7A94)` |
| その他 | `Color(0xFFF2F2F2)` | `Color(0xFF5A5A5A)` |

### 5-4. メンテナンス情報チップ（経過日数・ダイブ本数）
閾値を超えている場合のみアラートカラーを適用してください。

```dart
// 経過日数チップ
Container(
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: daysExceeded ? Color(0xFFFF5B5B).withOpacity(0.1) : Color(0xFFF0FAFE),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: daysExceeded ? Color(0xFFFF5B5B).withOpacity(0.4) : Color(0xFFE8F8FC),
    ),
  ),
  child: Row(children: [
    if (daysExceeded)
      PhosphorIcon(PhosphorIcons.warning(), size: 11, color: Color(0xFFFF5B5B)),
    SizedBox(width: 3),
    Text('経過 ${days}日',
      style: TextStyle(
        fontSize: 10,
        color: daysExceeded ? Color(0xFFFF5B5B) : Color(0xFF6B8FA0),
        fontWeight: daysExceeded ? FontWeight.w700 : FontWeight.w400,
      )),
  ]),
)
```

---

## 6. MarineLifeScreen（生物クエスト）

### 6-1. SkyCard
- title: `「${発見済み数} / ${総数}種を発見済み`
- subtitle: 「ダイビングで出会った生物を記録しよう」

### 6-2. カテゴリフィルターチップ
カテゴリ別カラーを以下に適用してください。

| カテゴリ | ドット色 | 選択時背景 | 非選択時背景 | 文字色（非選択） |
|---|---|---|---|---|
| かわいい系 | `#FF8FAB` | `#FF8FAB` | `#FFF0F4` | `#C42B5A` |
| ハゼ系 | `#4EC8E8` | `#4EC8E8` | `#E6F8FC` | `#1A7A94` |
| 幼魚系 | `#7BBF00` | `#7BBF00` | `#EEFACC` | `#5A8A00` |
| ハナダイ系 | `#D63A84` | `#D63A84` | `#FFE8F3` | `#D63A84` |
| ウミウシ系 | `#A78BFA` | `#A78BFA` | `#F1EEFF` | `#6D43D4` |
| 大物系 | `#FF9340` | `#FF9340` | `#FFF0E0` | `#C45A00` |
| 体験・現象系 | `#F5C400` | `#F5C400` | `#FFF6CC` | `#9A7200` |

- 「すべて」チップのみ: 背景 `Color(0xFF4EC8E8)`、文字 `Colors.white`、ドットなし
- 各チップの左端にカラードット（直径6px）を表示
- 選択時は背景をカテゴリ色、文字を `Colors.white` に変更

### 6-3. カテゴリ見出し（ExpansionTile）
- 左端に `CircleAvatar(radius: 8, backgroundColor: categoryColor)` を表示
- カテゴリ名: `fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A)`
- 件数: `fontSize: 11, color: Color(0xFF6B8FA0)`（例：「0 / 13」）

### 6-4. 生物リスト行
- 展開中のカテゴリ内ではカテゴリバッジを非表示にする（`すべて`表示時のみ表示）
- 発見済みの場合:
  - テキストに取り消し線: `TextDecoration.lineThrough`
  - テキスト色: `Color(0xFF6B8FA0)`
  - 右端に `PhosphorIcon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill), color: Color(0xFF4EC8E8), size: 18)`
- 未発見の場合:
  - 場所・時期の入力欄を `Color(0xFF6B8FA0)` / `fontSize: 11` で表示
  - 右端に `PhosphorIcon(PhosphorIcons.pencilSimple(), size: 16, color: Color(0xFFB0CDD5))`

---

## 7. CostScreen（コストレポート）

### 7-1. SkyCard
- title: `「累計 ¥${totalCost.toLocaleString()}`
- subtitle: `「ダイブ単価 ¥${unitCost} / 本」`

### 7-2. サマリーカード
数値カラーを以下に統一してください。

| 項目 | 数値色 |
|---|---|
| 累計コスト | `Color(0xFF4EC8E8)` |
| ダイブ単価 | `Color(0xFFFF9340)` |
| 累計ダイブ費 | `Color(0xFF4EC8E8)` |
| 累計宿泊費 | `Color(0xFF6B8FA0)` |
| 累計交通費 | `Color(0xFF6B8FA0)` |
| 累計ダイブ本数 | `Color(0xFF4EC8E8)` |

- ラベル: `fontSize: 11, color: Color(0xFF6B8FA0)`
- 数値: `fontSize: 16, fontWeight: FontWeight.w700`
- カード背景: `Color(0xFF4EC8E8).withOpacity(0.08)`
- カードボーダー: `Color(0xFF4EC8E8).withOpacity(0.25)`
- 角丸: `BorderRadius.circular(8)`

### 7-3. 集計テーブル（TabBar）
- 選択中タブの色: `Color(0xFF4EC8E8)`
- インジケーター色: `Color(0xFF4EC8E8)`

### 7-4. グラフ（fl_chart）
- 棒グラフ: `Color(0xFF4EC8E8).withOpacity(0.7)`
- 折れ線グラフ: `Color(0xFFFF9340)`
- グリッド線: `Color(0xFFE8F8FC)`
- 軸ラベル: `fontSize: 10, color: Color(0xFF6B8FA0)`

### 7-5. セクション見出し
各セクション（サマリー・集計テーブル・グラフ）の見出し左端に追加してください。

```dart
Row(children: [
  Container(
    width: 8, height: 8,
    decoration: BoxDecoration(
      color: Color(0xFF4EC8E8),
      shape: BoxShape.circle,
    ),
  ),
  SizedBox(width: 6),
  Text('サマリー',
    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
])
```

---

## 8. TemplateScreen（テンプレート）

### 8-1. SkyCard
- title: 「準備リストを設定」
- subtitle: 「テンプレートを選んでカスタマイズ」

### 8-2. 保存済みテンプレートチップ → カード化
現在の小さいチップ表示を、旅行カードと同スタイルのカードに変更してください。

```dart
// テンプレートカード
Container(
  margin: EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Color(0xFFE8F8FC), width: 1.5),
  ),
  child: Row(children: [
    // 左端カラーバー
    Container(width: 5, color: Color(0xFF4EC8E8)),
    Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A3A4A))),
            SizedBox(height: 3),
            Text('${template.suitType}・${template.tripType}・${template.entry}',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B8FA0))),
          ],
        ),
      ),
    ),
    // 編集・削除ボタン
    TextButton(onPressed: onEdit,
      child: Text('編集', style: TextStyle(color: Color(0xFF4EC8E8), fontSize: 12))),
    IconButton(
      onPressed: onDelete,
      icon: PhosphorIcon(PhosphorIcons.trash(), size: 18, color: Color(0xFFFF5B5B))),
  ]),
)
```

### 8-3. 「一覧を見る →」リンク
- 色: `Color(0xFF4EC8E8)`
- `fontSize: 13, fontWeight: FontWeight.w600`
- 右端に `PhosphorIcons.arrowRight()` アイコンを追加

### 8-4. セグメントコントロール（スーツ種類・旅行タイプ・エントリー）
- 選択中: 背景 `Color(0xFF4EC8E8)`、文字 `Colors.white`
- 非選択: 背景 `Colors.white`、文字 `Color(0xFF6B8FA0)`、ボーダー `Color(0xFFE8F8FC)`

### 8-5. 「このテンプレートを保存」ボタン
- `FilledButton`
- 背景色: `Color(0xFF4EC8E8)`
- 角丸: `BorderRadius.circular(12)`
- 幅: 全幅（`SizedBox(width: double.infinity, ...)`）

---

## 実装の優先順位

1. `ThemeData` の更新・Phosphor Icons の導入（全画面に影響）
2. `SkyCard` ウィジェットの新規作成
3. `BottomNavigationBar` のドットインジケーター追加
4. `TripDetailScreen` — 進捗バー・タスクカード・カテゴリ見出し
5. `TravelScreen` — 旅行カード・ステータスチップ
6. `EquipmentScreen` — タイプバッジ・アラートチップ
7. `MarineLifeScreen` — カテゴリチップ・生物リスト行
8. `CostScreen` — サマリーカード・グラフ色
9. `TemplateScreen` — テンプレートカード化

各画面の実装後、`design-regulation.md` の「Do / Don't」セクションに照らして確認してください。
