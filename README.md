# HAND LOG（独立Webアプリ版）セットアップ手順

誰でもリンクから登録して使えるポーカー記録アプリです。
**Supabase**（ログインとデータ保存）、**Vercel**（ページの公開とAIコーチのサーバー）、**Claude API**（AIコーチ）の3つを使います。

所要時間の目安：30〜45分（初回のみ）

---

## フォルダの中身

| ファイル | 役割 |
|---|---|
| `index.html` | アプリ本体 |
| `config.js` | Supabase の接続先（手順1で書き換える） |
| `api/coach.js` | AIコーチのサーバー処理（APIキーはここではなく Vercel に設定） |
| `supabase/schema.sql` | データベースの表と権限ルール |
| `manifest.webmanifest` / `sw.js` / `icons/` | ホーム画面に追加・オフライン起動用 |
| `vercel.json` | Vercel の設定 |

---

## 手順0：今のアプリのデータを控えておく（任意）

Claude 上の今の HAND LOG を開き、**設定 → バックアップ(JSON)をコピー** を押して、メモアプリなどに貼り付けて保存しておきます。新しいアプリでログインしたあと、**設定 → JSONから復元** に貼れば引き継げます。

---

## 手順1：Supabase（ログインと保存）

1. https://supabase.com でアカウントを作る（GitHub アカウントでログインすると楽）。
2. **New project** を作成。
   - Region：**Northeast Asia (Tokyo)**
   - Database Password：自分で決めて控えておく
3. 左メニュー **SQL Editor** → 新しいクエリ → `supabase/schema.sql` の中身を全部貼り付けて **Run**。「Success」と出ればOK。
4. 左メニュー **Project Settings → API**（「API Keys」「Data API」と表示される場合もあります）を開き、次の2つをコピー。
   - **Project URL**（`https://xxxx.supabase.co`）
   - **anon / publishable キー**（⚠ `service_role` / `secret` キーは絶対に使わない）
5. `config.js` を開いて、2つの値を貼り付けて保存。

```js
window.HANDLOG_CONFIG = {
  supabaseUrl: 'https://xxxx.supabase.co',
  supabaseAnonKey: 'eyJhbGciOi...'
};
```

> **メール確認について**：初期設定では、新規登録すると確認メールが届き、リンクを開くまでログインできません。Supabase 標準のメール送信は1時間あたりの送信数がかなり少ないので、たくさんの人に公開する前に **Authentication → Emails** で自分のメール送信サービス（SMTP）を設定するか、**Authentication → Sign In / Providers → Email** の「Confirm email」をオフにしてください。

---

## 手順2：Claude API キー（AIコーチ用）

1. https://console.anthropic.com でアカウントを作る。
2. **Billing** でクレジットを購入（AIコーチの利用料はここから引かれます）。
3. **使いすぎ防止のため、利用上限（Limits）を設定**しておくのがおすすめ。
4. **API Keys → Create Key** でキーを作ってコピー（`sk-ant-...`）。このキーは誰にも見せないこと。

> アプリ側でも「1人1日3回まで」の制限をかけています（手順4で変更可）。

---

## 手順3：GitHub にファイルを置く

1. https://github.com でアカウントを作る。
2. 右上の **＋ → New repository**。名前は `handlog` など、**Private** でOK → Create。
3. 「**uploading an existing file**」のリンクを押し、このフォルダの**中身を全部**（`api`、`icons`、`supabase` フォルダごと）ドラッグ＆ドロップ → **Commit changes**。

---

## 手順4：Vercel で公開する

1. https://vercel.com を開き、**GitHub でログイン**。
2. **Add New → Project** → さっきの `handlog` を **Import**。
3. Framework Preset は **Other** のまま。
4. **Environment Variables** に次を追加。

| Name | Value |
|---|---|
| `ANTHROPIC_API_KEY` | 手順2のキー |
| `SUPABASE_URL` | 手順1の Project URL |
| `SUPABASE_ANON_KEY` | 手順1の anon キー |
| `COACH_DAILY_LIMIT` | 1人1日あたりの回数（例 `3`、省略可） |

5. **Deploy**。1分ほどで `https://handlog-xxxx.vercel.app` のような URL ができます。
6. Supabase に戻り、**Authentication → URL Configuration** の **Site URL** にこの URL を入れ、**Redirect URLs** にも同じ URL を追加して保存（確認メールやパスワード再設定のリンクがここに戻ってきます）。

---

## 手順5：自分を管理者にする

1. 公開した URL を開き、**新規登録**して自分のアカウントを作る。
2. Supabase の **SQL Editor** で、メールアドレスを自分のものに変えて実行。

```sql
insert into public.admins (user_id)
  select id from auth.users where email = 'あなたのメールアドレス';
```

3. アプリを開き直すと、上部に **ADMIN**、タブに **みんな** が出ます（全員の成績一覧と全ハンドDB）。

---

## 手順6：スマホのホーム画面に追加

- **iPhone（Safari）**：共有ボタン → **ホーム画面に追加**
- **Android（Chrome）**：︙ → **ホーム画面に追加**（または「アプリをインストール」）

普通のアプリのように全画面で開き、電波がない場所でも記録できます（つながったときに自動で同期）。

---

## あとから変更するとき

GitHub 上のファイルを編集（またはアップロードし直し）すると、Vercel が自動で公開し直します。

## 費用の目安

- **Supabase / Vercel**：小規模なら無料プランで動きます。ただし Supabase の無料プランは、しばらく誰もアクセスしないとプロジェクトが一時停止されることがあります（管理画面から再開できます）。Vercel の無料プラン（Hobby）は個人・非商用向けです。
- **Claude API**：AIコーチを使った回数に応じて、手順2のクレジットから引かれます。

## 安全のしくみ

- 各利用者は**自分のデータだけ**読み書きできます（データベース側の権限ルールで制限）。
- **管理者は全員のデータを読めます**が、他人のデータを書き換えることはできません。利用者の設定画面には「運営者も見られる」ことを表示しています。
- Claude API キーは Vercel のサーバーにだけ置かれ、利用者のスマホには渡りません。
