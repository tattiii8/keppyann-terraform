# Podcast S3 + CloudFront infrastructure

Terraform Cloud を前提に、既存の Podcast URL を維持したまま
オンプレ Apache + Cloudflare Tunnel から S3 + CloudFront へ移行するための
最小構成です。

## Architecture

```text
Apple Podcasts
      |
      v
verlaine.lesure.net
      |
      v
Cloudflare DNS
      |
      v
CloudFront
      |
      | Origin Access Control
      v
S3 (private)
  |- feed.xml
  |- arch/
  |    |- 1....
  |    |- ...
  |    `- 63.トーク・ハラスメント.m4a
  `- healthcheck.txt
```

Cloudflare Tunnel はこの構成では不要です。
Cloudflare DNS は継続利用できます。

## Terraform Cloud

GitHub リポジトリの `/runtime` を Terraform Cloud Workspace の
**Working Directory** に設定してください。

AWS 認証は Terraform Cloud の環境変数または
dynamic credentials を利用してください。

## ACM

CloudFront 用 ACM 証明書は `us-east-1` に作成する必要があります。

1. `acm_validation_wait = false` で Apply
2. `terraform output acm_validation_records` を確認
3. Cloudflare DNS に表示された CNAME を登録
   - Cloudflare proxy は DNS only を推奨
4. `acm_validation_wait = true` に変更して Apply

Terraform Cloud では `terraform output` をローカルから実行できない場合、
Terraform Cloud の Outputs 画面で同じ値を確認できます。

## 既存ファイルの移行

現在の共有フォルダ:

```text
\\192.168.8.30\arch
```

から、S3 の `arch/` prefix にコピーします。

例:

```powershell
aws s3 sync "\\192.168.8.30\arch" "s3://YOUR_BUCKET/arch"
```

S3 の bucket 名は Terraform の output `s3_bucket_name` を使用してください。

既存 RSS の enclosure URL を維持するため、既存ファイル名・パスを
そのまま `arch/` 配下へコピーする方式を推奨します。

## feed.xml

既存 RSS をまずそのまま S3 に配置できます。

```powershell
aws s3 cp ".\feed.xml" "s3://YOUR_BUCKET/feed.xml" --content-type "application/rss+xml; charset=utf-8"
```

## 動作確認

Terraform Apply 後、CloudFront のドメインで確認します。

```text
https://CLOUDFRONT_DOMAIN/healthcheck.txt
```

ただし ACM の証明書は独自ドメイン用なので、CloudFront のデフォルトドメイン
へ HTTPS でアクセスする場合は証明書の hostname が一致しません。

最終的な確認は DNS を CloudFront に切り替えた後、

```text
https://verlaine.lesure.net/healthcheck.txt
https://verlaine.lesure.net/feed.xml
https://verlaine.lesure.net/arch/63.トーク・ハラスメント.m4a
```

で行います。

HTTP ヘッダー確認:

```bash
curl -I "https://verlaine.lesure.net/arch/63.トーク・ハラスメント.m4a"
```

Range Request:

```bash
curl -v -r 0-1023 -o /dev/null \
  "https://verlaine.lesure.net/arch/63.トーク・ハラスメント.m4a"
```

確認ポイント:

- HTTP 200
- `Content-Type` が音声ファイルとして正しい
- `Content-Length`
- Range Request が `206 Partial Content`
- `Accept-Ranges: bytes`
- `X-Cache` / `Age` など CloudFront のキャッシュヘッダー

## 移行手順

1. Terraform Cloud から AWS リソースを作成
2. S3 に既存 `arch/` をコピー
3. S3 に既存 `feed.xml` をコピー
4. ACM DNS validation を完了
5. Cloudflare DNS の `verlaine.lesure.net` を CloudFront に変更
6. Podcast URL、RSS、音声、Range Request を確認
7. Cloudflare の旧 Tunnel を停止
8. オンプレ Apache / サーバーを停止

DNS 切り替え前に S3/CloudFront 側を完成させるため、
実際のサービス停止時間を最小化できます。

## Cloudflare DNS

Cloudflare を DNS として使う場合は、CloudFront の distribution domain を
CNAME の target にします。

```text
verlaine.lesure.net CNAME dxxxxxxxxxxxx.cloudfront.net
```

CloudFront は HTTPS を要求するため、ACM certificate の検証を完了してから
DNS を切り替えてください。

Cloudflare proxy (orange cloud) を利用する場合は、
Cloudflare 側の SSL/TLS mode を Full (strict) にしてください。

より単純な構成にするなら DNS only でも構いません。

## 注意

この Terraform は S3/CloudFront の「インフラ」を作ります。
Podcast の音声ファイル、RSS、DynamoDB などのコンテンツ/アプリケーション
管理は含めていません。

また、既存 URL を維持することを優先し、S3 object key は既存の
`arch/...` をそのまま使う設計です。
