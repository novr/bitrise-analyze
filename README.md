# bitrise-analyze

Bitrise APIを使用してビルドデータを分析・取得するSwiftコマンドラインツールです。CI環境移行のための包括的なデータ分析機能を提供します。

## 概要

このツールは、Bitrise APIを通じてビルド情報を取得し、詳細な統計分析とレポート生成を行います。OpenAPI Generatorを使用して生成されたクライアントコードを利用し、認証ミドルウェアとカスタムミドルウェアを組み合わせてAPIとの通信を行います。

## 機能

### データ取得機能
- Bitrise APIからビルドデータを一括取得
- ページネーション対応（全データを自動的に取得）
- 認証トークンによるAPIアクセス
- JSON形式でのデータ出力
- デバッグ用のcurlコマンド出力（オプション）

### データ分析機能
- **期間別統計**: 7日、30日、90日、全期間の集計
- **リポジトリ別分析**: アプリごとの詳細統計
- **ワークフロー分析**: 実行回数、成功率、実行時間の分析
- **時間帯分析**: ピーク時間帯、曜日別の実行パターン
- **リソース使用状況**: マシンタイプ別の使用頻度とコスト
- **パフォーマンス指標**: 実行時間の統計（平均、中央値、パーセンタイル）

## 要件

- macOS 13.0以上
- Swift 5.9以上

## インストール

### Swift Package Managerを使用

```bash
git clone <repository-url>
cd bitrise-analyze
swift build
```

## 使用方法

### データ取得

#### 基本的な使用方法

```bash
swift run bitrise-analyze --token YOUR_BITRISE_ACCESS_TOKEN
```

#### オプション

- `--token`: Bitriseアクセストークン（環境変数`BITRISE_ACCESS_TOKEN`からも取得可能）
- `--output`: 出力ファイル名（デフォルト: `data.json`）
- `--streaming`: ストリーミングモードで処理（大量データ用）

#### 環境変数を使用

```bash
export BITRISE_ACCESS_TOKEN=your_token_here
swift run bitrise-analyze
```

### データ分析・集計

#### 基本的な集計実行

```bash
swift run bitrise-analyze aggregate
```

#### 集計オプション

- `--input`: データファイルのパス（デフォルト: `data.json`）
- `--output`: 出力ディレクトリ（デフォルト: `output`）
- `--verbose`: 詳細なログを表示

#### カスタム分析

```bash
# カスタムデータファイルを指定
swift run bitrise-analyze aggregate --input custom_data.json --output custom_output

# 詳細ログ付きで実行
swift run bitrise-analyze aggregate --verbose
```

## 出力

### データ取得の出力

ツールは指定されたファイル（デフォルト: `data.json`）に以下の形式でデータを出力します：

```json
{
  "data": [
    {
      // ビルド情報の配列
    }
  ],
  "paging": {
    // ページネーション情報
  }
}
```

### 集計分析の出力

`aggregate`コマンドを実行すると、`output/`ディレクトリに以下のファイルが生成されます：

#### CSVファイル（Excel等での分析用）

- **`builds_summary.csv`** - 期間別の基本統計
  - 総ビルド数、成功率、実行時間統計（平均、中央値、パーセンタイル）
  
- **`repository_stats.csv`** - リポジトリ別の詳細統計
  - 各アプリの期間別統計、主要ワークフロー、失敗率の高いワークフロー
  
- **`workflow_stats.csv`** - ワークフロー別の詳細統計
  - 実行回数、成功率、平均実行時間、失敗回数
  
- **`daily_trends.csv`** - 日別トレンドデータ
  - 日別のビルド数、成功率、平均実行時間
  
- **`hourly_distribution.csv`** - 時間帯別分布
  - 0-23時の時間帯別ビルド数と成功率
  
- **`machine_type_stats.csv`** - マシンタイプ別統計
  - 使用頻度、実行時間、コスト分析

#### Markdownレポート

- **`report_7日.md`** - 7日期間の詳細レポート
- **`report_30日.md`** - 30日期間の詳細レポート  
- **`report_90日.md`** - 90日期間の詳細レポート
- **`report_全期間.md`** - 全期間の詳細レポート

### コンソール出力

集計実行時には、各期間の要約統計がコンソールに表示されます：

```
============================================================
📊 Bitrise ビルド統計サマリー
============================================================

📈 7日期間:
  📦 総ビルド数: 300
  ✅ 成功: 231 (77.0%)
  ❌ 失敗: 36
  ⏹️  中断: 33
  ⏱️  平均実行時間: 11m 25s
  📊 中央値: 9m 23s
  💰 総コスト: 0 credits
```

## アーキテクチャ

### 主要コンポーネント

#### データ取得
- **Analyze.swift**: メインのコマンドラインインターフェース
- **BitriseClient.swift**: Bitrise APIクライアント
- **AuthenticationMiddleware.swift**: API認証用ミドルウェア
- **CurlMiddleware.swift**: デバッグ用curlコマンド出力ミドルウェア
- **StreamingJSONWriter.swift**: ストリーミングJSON出力

#### データ分析
- **AggregateStats.swift**: データ集計・分析機能
- **openapi.yaml**: Bitrise APIのOpenAPI仕様書
- **openapi-generator-config.yaml**: OpenAPI Generatorの設定

### 依存関係

- [swift-openapi-generator](https://github.com/apple/swift-openapi-generator): OpenAPIクライアント生成
- [swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime): OpenAPIランタイム
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession): URLSessionトランスポート
- [swift-argument-parser](https://github.com/apple/swift-argument-parser): コマンドライン引数解析

## 開発

### ビルド

```bash
swift build
```

### 実行

```bash
# ヘルプを表示
swift run bitrise-analyze --help

# 集計機能のヘルプを表示
swift run bitrise-analyze aggregate --help
```

### OpenAPIクライアントの再生成

OpenAPI仕様書が更新された場合、以下のコマンドでクライアントコードを再生成できます：

```bash
swift package resolve
swift build
```

## 使用例

### CI環境移行のための分析

```bash
# 1. データを取得
swift run bitrise-analyze --token YOUR_TOKEN --output bitrise_data.json

# 2. 集計・分析を実行
swift run bitrise-analyze aggregate --input bitrise_data.json --output analysis_results

# 3. 生成されたCSVファイルをExcel等で開いて詳細分析
open analysis_results/repository_stats.csv
```

### 特定期間の分析

```bash
# 詳細ログ付きで実行
swift run bitrise-analyze aggregate --verbose

# 出力されるファイル:
# - repository_stats.csv: リポジトリ別の詳細統計
# - workflow_stats.csv: ワークフロー別の統計
# - daily_trends.csv: 日別トレンド
# - hourly_distribution.csv: 時間帯別分布
# - machine_type_stats.csv: マシンタイプ別統計
```

## ライセンス

このプロジェクトのライセンスについては、プロジェクトのルートディレクトリにあるLICENSEファイルを確認してください。

## 貢献

プルリクエストやイシューの報告を歓迎します。貢献する前に、既存のイシューを確認し、新しいイシューを作成する前に議論してください。

## サポート

問題が発生した場合は、GitHubのイシューページで報告してください。
