# デザインレギュレーション — Sunny Sky（案B-1）
## ダイビング準備アプリ向け

海・空・太陽をモチーフにした、明るく可愛めの世界観を全画面で一貫して実装してください。
Flutter（Dart）で実装するネイティブアプリです。

> **方針**: 既存コードのカラーコードには縛られません。このレギュレーションのパレットに全面的に統一してください。

---

## 0. アプリ画面構成

### ボトムナビゲーション（5タブ）

| # | タブ名 | Screen | 主な機能 |
|---|--------|--------|---------|
| 1 | 旅行準備 | `TravelScreen` | カレンダー表示・旅行追加・旅行カード一覧 |
| 2 | 器材 | `EquipmentScreen` | マイ器材リスト・メンテナンスアラート |
| 3 | 生物図鑑 | `MarineLifeScreen` | 見たい生物チェックリスト（カテゴリ別） |
| 4 | コスト | `CostScreen` | コストレポート・グラフ・集計テーブル |
| 5 | テンプレート | `TemplateScreen` | 準備リストテンプレートの作成・管理 |

### サブページ（画面遷移）

| Screen | 遷移元 | 主な機能 |
|--------|--------|---------|
| `TripDetailScreen` | 旅行準備タブ | 旅行詳細・チェックリスト・コスト入力 |

---

## 1. カラーパレット

### ベースカラー

| 役割 | 名前 | HEX | Flutter |
|------|------|-----|---------|
| Primary（空・海） | Sky Blue | `#4EC8E8` | `Color(0xFF4EC8E8)` |
| Background | Off White | `#F9FEFF` | `Color(0xFFF9FEFF)` |
| Surface（カード） | White | `#FFFFFF` | `Colors.white` |
| Text Primary | Deep Navy | `#1A3A4A` | `Color(0xFF1A3A4A)` |
| Text Secondary | Muted Blue | `#6B8FA0` | `Color(0xFF6B8FA0)` |
| Border | Light Cyan | `#E8F8FC` | `Color(0xFFE8F8FC)` |

### アクセントカラー

| 役割 | 名前 | HEX | Flutter | 使用箇所 |
|------|------|-----|---------|---------|
| 太陽 | Sun Yellow | `#FFD233` | `Color(0xFFFFD233)` | ヒーローカード装飾・強調バッジ |
| アクション | Sunset Orange | `#FF9340` | `Color(0xFFFF9340)` | 主要CTAボタン（旅行追加等） |

### カテゴリカラー（生物図鑑・フィルター共通）

チップ・バッジ・カテゴリドットに一貫して使用します。背景や大面積には使いません。

| カテゴリ | ドット・ボーダー | チップ背景 | チップ文字 | Flutter（ドット） |
|---------|--------------|----------|----------|----------------|
| かわいい系 | `#FF8FAB` | `#FFF0F4` | `#C42B5A` | `Color(0xFFFF8FAB)` |
| ハゼ系 | `#4EC8E8` | `#E6F8FC` | `#1A7A94` | `Color(0xFF4EC8E8)` |
| 幼魚系 | `#7BBF00` | `#EEFACC` | `#5A8A00` | `Color(0xFF7BBF00)` |
| ハナダイ系 | `#D63A84` | `#FFE8F3` | `#D63A84` | `Color(0xFFD63A84)` |
| ウミウシ系 | `#A78BFA` | `#F1EEFF` | `#6D43D4` | `Color(0xFFA78BFA)` |
| 大物系 | `#FF9340` | `#FFF0E0` | `#C45A00` | `Color(0xFFFF9340)` |
| 体験・現象系 | `#F5C400` | `#FFF6CC` | `#9A7200` | `Color(0xFFF5C400)` |

### 器材タイプカラー（EquipmentScreen）

| 器材種類 | HEX | Flutter |
|---------|-----|---------|
| BCD | `#4EC8E8` | `Color(0xFF4EC8E8)` |
| レギュレーター | `#7BBF00` | `Color(0xFF7BBF00)` |
| ドライスーツ | `#A78BFA` | `Color(0xFFA78BFA)` |
| ウェットスーツ | `#4EC8E8` | `Color(0xFF4EC8E8)` |
| その他 | `#B0CDD5` | `Color(0xFFB0CDD5)` |

### アラートカラー（器材メンテナンス）

| レベル | HEX | Flutter | 条件 |
|--------|-----|---------|------|
| 注意（Orange） | `#FF9340` | `Color(0xFFFF9340)` | 日数 or 本数いずれか超過 |
| 警告（Red） | `#FF5B5B` | `Color(0xFFFF5B5B)` | 日数・本数ともに超過 |

### ステータスチップカラー（旅行カード）

| 種別 | HEX | Flutter |
|------|-----|---------|
| ウェットスーツ | `#4EC8E8` | `Color(0xFF4EC8E8)` |
| ドライスーツ | `#A78BFA` | `Color(0xFFA78BFA)` |
| 宿泊 | `#FF9340` | `Color(0xFFFF9340)` |
| 日帰り | `#7BBF00` | `Color(0xFF7BBF00)` |

---

## 2. タイポグラフィ

| 役割 | サイズ | ウェイト | 色 |
|------|--------|---------|-----|
| 画面タイトル（AppBar） | 18px | w700 | `#1A3A4A` |
| カード・セクション見出し | 15–17px | w700 | `#1A3A4A` |
| 本文・リスト項目名 | 13–15px | w400–w600 | `#1A3A4A` |
| サブテキスト・補足 | 11–12px | w400 | `#6B8FA0` |
| バッジ・チップ | 10–11px | w600–w700 | カテゴリ色に準ずる |
| ヒーローカード数値 | 22–28px | w700 | `#FFFFFF` |
| グラフ軸ラベル | 9–11px | w400 | `#6B8FA0` |

- フォントファミリー: Flutter デフォルト（Roboto / Noto Sans JP）
- 行間: 本文 `1.5`、UI要素 `1.2`

---

## 3. コンポーネント仕様

### 3-1. ヒーローカード（Sky Card）

各画面上部に配置する、今日の情報や統計を見せるカード。

```dart
Container(
  margin: EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: Color(0xFF4EC8E8),
    borderRadius: BorderRadius.circular(16),
  ),
  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  height: 78,
)
```

装飾要素:
- 右上: 雲シェイプ（`background: rgba(255,255,255,0.45)`、`BorderRadius.circular(20)`）
- 右下: 太陽サークル（`Color(0xFFFFD233)`、直径28px、`BoxShape.circle`）
- テキストはすべて `Colors.white`

### 3-2. カテゴリフィルターチップ

横スクロールの `ListView` 内に配置。

```dart
GestureDetector(
  onTap: () => setState(() => _selectedCategory = cat),
  child: Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: isSelected ? categoryColor : categoryBgColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: categoryColor, width: 1.2),
    ),
    child: Row(children: [
      // カラードット（直径6px）
      Container(width: 6, height: 6,
        decoration: BoxDecoration(color: categoryColor, shape: BoxShape.circle)),
      SizedBox(width: 4),
      Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
        color: isSelected ? Colors.white : categoryTextColor)),
    ]),
  ),
)
```

- 「すべて」チップのみ: `background: #4EC8E8; color: #FFFFFF`（ドットなし）
- 選択中: カテゴリのメインカラーを背景に、文字は白
- 非選択: 薄い背景色＋カテゴリ文字色

### 3-3. タスク・チェックリストカード

`TripDetailScreen` のチェックリスト項目。

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Color(0xFFE8F8FC), width: 1.5),
  ),
)
```

チェックサークル（直径16px）:
- 未完了: `border: 2px solid #B0CDD5`
- 完了: `background: #4EC8E8; border-color: #4EC8E8` + チェックマーク（白）

カテゴリバッジ（右端）:
- 時刻バッジ: `background: #E6F8FF; color: #2A9DBF`
- カテゴリバッジ: カテゴリカラーパレット表に従う

### 3-4. 旅行カード（TripCard）

```dart
Card(
  margin: EdgeInsets.only(bottom: 10),
  elevation: 2,
  shadowColor: Colors.black12,
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
)
```

- 左端カラーバー（幅5px）: `Color(0xFF4EC8E8)`（Sky Blue 固定）
- タイトル: 17px / w700 / `#1A3A4A`
- サブテキスト: 12px / `#6B8FA0`
- ウェット/ドライ・宿泊/日帰りのステータスチップを横並び（`BorderRadius.circular(20)`）

### 3-5. 器材カード（EquipmentCard）

```dart
Card(
  margin: EdgeInsets.only(bottom: 10),
  elevation: 2,
  clipBehavior: Clip.antiAlias,
)
// アラートがある場合のみ左端に幅5pxのアラートカラーバー
```

- 器材タイプバッジ: `BorderRadius.circular(20)` + 各タイプカラーで白文字
- アラートバナー（カード下部）:
  - 背景: アラート色 `withOpacity(0.10)`
  - ボーダー: アラート色 `withOpacity(0.35)`
  - `BorderRadius.circular(8)`

### 3-6. コストサマリータイル

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: BoxDecoration(
    color: Color(0xFF4EC8E8).withOpacity(0.08),
    border: Border.all(color: Color(0xFF4EC8E8).withOpacity(0.25)),
    borderRadius: BorderRadius.circular(8),
  ),
)
```

- ラベル: 11px / `#6B8FA0`
- 値: 15px / w700 / `#4EC8E8`（または各メトリクスに応じたアクセント色）
- 2列グリッド（`Row` + 2つの `Expanded`）

### 3-7. ボトムナビゲーション

```dart
BottomNavigationBar(
  backgroundColor: Colors.white,
  selectedItemColor: Color(0xFF4EC8E8),
  unselectedItemColor: Color(0xFFB0CDD5),
  elevation: 0,
  // 上ボーダー: 1.5px solid #E8F8FC
)
```

アクティブアイテムの下: 直径4pxのドットインジケーター（`Color(0xFF4EC8E8)`）

### 3-8. 主要CTAボタン

```dart
// 主要アクション（旅行追加 等）
FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: Color(0xFFFF9340),  // Sunset Orange
    padding: EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
)

// セカンダリ（器材追加 等）
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: Color(0xFF4EC8E8),
    side: BorderSide(color: Color(0xFF4EC8E8)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
)
```

---

## 4. スペーシング

| 用途 | 値 |
|------|-----|
| 画面左右パディング | `16px` |
| カード間ギャップ | `10px`（`margin: EdgeInsets.only(bottom: 10)`） |
| カード内パディング | `12–16px` |
| チップ間ギャップ | `8px` |
| セクション間 | `12–20px` |
| AppBar 下の余白 | `6–10px` |

---

## 5. 角丸ルール

| 要素 | `borderRadius` |
|------|---------------|
| ヒーローカード | `16px` |
| 旅行・器材カード | `12px` |
| タスクカード | `12px` |
| コストサマリータイル | `8px` |
| チップ・ピル形バッジ | `20px` |
| アラートバナー | `8px` |
| CTAボタン | `12px` |
| カレンダー選択日 | `BoxShape.circle` |

---

## 6. アイコン

### ライブラリ

**Phosphor Icons**（`phosphor_flutter`）を使用します。Material Icons からの移行対象です。

```yaml
# pubspec.yaml
dependencies:
  phosphor_flutter: ^2.1.0
```

```dart
// 基本の使い方
PhosphorIcon(PhosphorIcons.wave())           // regular（デフォルト）
PhosphorIcon(PhosphorIcons.wave(PhosphorIconsStyle.bold))  // bold
PhosphorIcon(PhosphorIcons.wave(PhosphorIconsStyle.fill))  // fill
```

- スタイル: **regular（アウトライン）** を基本とし、アクティブ状態のナビゲーションアイコンのみ **fill** を使用
- サイズ: ナビゲーション 24px、カード内 18–20px、インライン装飾 14–16px
- 色: 親要素の指定に従う（`color` プロパティで渡す）

### ナビゲーションアイコン（BottomNavigationBar）

| タブ | 非アクティブ（regular） | アクティブ（fill） |
|------|----------------------|-----------------|
| 旅行準備 | `PhosphorIcons.airplane()` | `PhosphorIcons.airplane(PhosphorIconsStyle.fill)` |
| 器材 | `PhosphorIcons.scubaMask()` | `PhosphorIcons.scubaMask(PhosphorIconsStyle.fill)` |
| 生物図鑑 | `PhosphorIcons.fish()` | `PhosphorIcons.fish(PhosphorIconsStyle.fill)` |
| コスト | `PhosphorIcons.chartBar()` | `PhosphorIcons.chartBar(PhosphorIconsStyle.fill)` |
| テンプレート | `PhosphorIcons.listChecks()` | `PhosphorIcons.listChecks(PhosphorIconsStyle.fill)` |

### 画面内アイコン一覧

| 用途 | アイコン | サイズ | 色 |
|------|---------|--------|-----|
| 場所 | `PhosphorIcons.mapPin()` | 14px | `#6B8FA0` |
| 日付・カレンダー | `PhosphorIcons.calendarBlank()` | 14px | `#6B8FA0` |
| 旅行追加 | `PhosphorIcons.plus()` | 18px | `#FFFFFF` |
| 編集 | `PhosphorIcons.pencilSimple()` | 16px | `#6B8FA0` |
| 削除 | `PhosphorIcons.trash()` | 16px | `#FF5B5B` |
| 複製 | `PhosphorIcons.copy()` | 16px | `#6B8FA0` |
| メンテナンス（器材） | `PhosphorIcons.wrench()` | 16px | `#6B8FA0` |
| 購入日（器材） | `PhosphorIcons.shoppingBag()` | 16px | `#6B8FA0` |
| アラート警告 | `PhosphorIcons.warning()` | 18px | アラートカラー |
| チェック完了 | `PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)` | 18px | `#4EC8E8` |
| 旅行カードメニュー | `PhosphorIcons.dotsThreeVertical()` | 20px | `#6B8FA0` |
| 空データ（旅行） | `PhosphorIcons.airplane()` | 48px | `#B0CDD5` |
| 空データ（器材） | `PhosphorIcons.backpack()` | 48px | `#B0CDD5` |
| 空データ（生物図鑑） | `PhosphorIcons.fish()` | 48px | `#B0CDD5` |
| ウェットスーツ | `PhosphorIcons.waves()` | 16px | ステータス色 |
| ドライスーツ | `PhosphorIcons.snowflake()` | 16px | ステータス色 |
| 宿泊 | `PhosphorIcons.bed()` | 16px | ステータス色 |
| 日帰り | `PhosphorIcons.sun()` | 16px | ステータス色 |

---

## 7. インタラクション

| 状態 | 仕様 |
|------|------|
| チップ選択 | 背景をカテゴリカラーに変化、文字を白に |
| タスク完了 | チェック円を `#4EC8E8` 塗りに。取り消し線は生物図鑑のみ、チェックリストには**つけない** |
| カードタップ | `InkWell` リップル（デフォルト） |
| カード長押し | カスタム生物アイテムの削除ダイアログ表示 |
| ポップアップメニュー | 旅行カードの複製・削除（`PopupMenuButton`） |
| カレンダーの旅行日 | Sky Blue の円ボーダー（`Color(0xFF4EC8E8)`、`width: 2`） |

---

## 8. 画面別デザインポイント

### 旅行準備（TravelScreen）
- `TableCalendar` を最上部に配置
- 旅行がある日付: Sky Blue の円ボーダー（塗りなし）＋テキストを `#4EC8E8` / w700
- 選択日: Sky Blue の塗りつぶし円
- 「旅行を追加」ボタン: `FilledButton`、`Sunset Orange (#FF9340)`

### 旅行詳細（TripDetailScreen）
- チェックリスト項目をカテゴリ別に表示
- 各カテゴリヘッダーに Sky Blue のアクセントドット
- コスト入力セクションを同画面内に統合

### 器材（EquipmentScreen）
- アラートなし器材: 左端カラーバーなし
- アラートあり器材: 左端 5px のアラートカラーバー
- 「器材を追加」ボタン: `OutlinedButton` / Sky Blue

### 生物図鑑（MarineLifeScreen）
- カテゴリ横スクロールチップ → `ExpansionTile` で一覧
- カテゴリヘッダー左端に `CircleAvatar`（radius: 8）でカテゴリカラーを表示
- 発見済み: 取り消し線 + `Icons.check_circle`（`Color(0xFF4EC8E8)`）
- 発見数サマリー: 「X／Y 種を発見済み」を `#6B8FA0` で表示

### コスト（CostScreen）
- サマリー → 集計テーブル（TabBar 3タブ）→ グラフの順で縦スクロール
- グラフ棒: `Color(0xFF4EC8E8).withOpacity(0.65)`
- グラフ折れ線: `Color(0xFFFF9340)`（Sunset Orange）
- セクション見出し左端: `Icon(Icons.circle, size: 10, color: Color(0xFF4EC8E8))`

### テンプレート（TemplateScreen）
- テンプレートカードは旅行カードと同スタイルで統一
- 左端カラーバーは `Color(0xFF4EC8E8)`

---

## 9. Flutter ThemeData 設定例

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
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: Color(0xFFFF9340),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
)
```

---

## 10. 世界観ガイドライン（Do / Don't）

### ✅ Do
- Sky Blue (`#4EC8E8`) を基軸に、海・空・太陽のモチーフを要所に使う
- カテゴリカラーは小面積（チップ・バッジ・ドット）のアクセントのみに使用
- 余白を十分に取り、すっきりした印象を保つ
- `ThemeData` に色をセットして `Theme.of(context).colorScheme.primary` で統一参照
- アラートは Orange → Red の2段階で視覚的な優先度を表現

### ❌ Don't
- 既存コードのカラーコードをそのまま流用しない（このドキュメントに統一）
- カテゴリカラーを背景や大面積に使わない
- `Card` の `elevation` を `3` 以上にしない
- ダーク系・くすんだ背景を使わない
- 文字サイズを `11px` 未満にしない
- AppBar の背景色を変えない（`Colors.white` 固定）
