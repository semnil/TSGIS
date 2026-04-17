# TSGIS

Steam ゲーム情報収集機のバックエンド (Lambda + API Gateway + DynamoDB)。

公開フロントエンド: [https://semnil.com/game/](https://semnil.com/game/)

## リポジトリ構成

本リポジトリはバックエンド (Lambda 関数 + SAM テンプレート) のみを管理する。フロントエンド (HTML/JS) は別リポジトリ [semnil/semnil.com](https://github.com/semnil/semnil.com) の `www/game/` 配下で管理している。

- `lambda/` — Lambda 関数ソースと SAM テンプレート
- `docs/` — 設計・移行ドキュメント
- `buildspec.yml` — CodeBuild 定義

## 利用する外部サービス

- Steam Store Search API  
  `https://store.steampowered.com/api/storesearch/` (認証不要)
- AWS API Gateway — Lambda Proxy
- AWS Lambda
  - [steamGame](lambda/steamGame)
  - [historySteamGame](lambda/historySteamGame)

## 移行メモ

元は Google Custom Search JSON API をバックエンドに利用していたが、2026-04 に Steam Store Search API へ移行した。経緯は [docs/migration-from-google-custom-search.md](docs/migration-from-google-custom-search.md) を参照。
