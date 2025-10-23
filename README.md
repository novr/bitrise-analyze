# bitrise-analyze

Bitrise APIを使用してビルドデータを分析・取得するSwiftコマンドラインツールです。

## 概要

このツールは、Bitrise APIを通じてビルド情報を取得し、JSONファイルとして出力します。OpenAPI Generatorを使用して生成されたクライアントコードを利用し、認証ミドルウェアとカスタムミドルウェアを組み合わせてAPIとの通信を行います。

## 機能

- Bitrise APIからビルドデータを一括取得
- ページネーション対応（全データを自動的に取得）
- 認証トークンによるAPIアクセス
- JSON形式でのデータ出力
- デバッグ用のcurlコマンド出力（オプション）

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

### 基本的な使用方法

```bash
swift run bitrise-analyze --token YOUR_BITRISE_ACCESS_TOKEN
```

### オプション

- `--token`: Bitriseアクセストークン（環境変数`BITRISE_ACCESS_TOKEN`からも取得可能）
- `--output`: 出力ファイル名（デフォルト: `data.json`）

### 環境変数を使用

```bash
export BITRISE_ACCESS_TOKEN=your_token_here
swift run bitrise-analyze
```

## 出力

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

## アーキテクチャ

### 主要コンポーネント

- **Analyze.swift**: メインのコマンドラインインターフェース
- **AuthenticationMiddleware.swift**: API認証用ミドルウェア
- **CurlMiddleware.swift**: デバッグ用curlコマンド出力ミドルウェア
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
swift run bitrise-analyze --help
```

### OpenAPIクライアントの再生成

OpenAPI仕様書が更新された場合、以下のコマンドでクライアントコードを再生成できます：

```bash
swift package resolve
swift build
```

## ライセンス

このプロジェクトのライセンスについては、プロジェクトのルートディレクトリにあるLICENSEファイルを確認してください。

## 貢献

プルリクエストやイシューの報告を歓迎します。貢献する前に、既存のイシューを確認し、新しいイシューを作成する前に議論してください。

## サポート

問題が発生した場合は、GitHubのイシューページで報告してください。
