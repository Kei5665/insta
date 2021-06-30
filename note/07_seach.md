## 実装内容
- 全ての投稿を検索対象とする（フィードに対する検索ではない）
- 本文に検索ワードが含まれている投稿の検索。半角スペースでつなげることでor検索ができるようにする。e.g.「rails ruby」
- コメントに検索ワードが含まれている投稿の検索
- 投稿者の名前に検索ワードが含まれている投稿の検索
- ransackなどの検索用のGemは使わず、フォームオブジェクト、ActiveModelを使って実装する
- 検索時のパスは/posts/searchとする

# 実装について
## 最初にざっくりまとめる
検索機能を3つの要素に分解
1. 入力フォームで入力された値を受け取り、変数へ格納
2. 値が入っている変数に対して検索メソッドを実行し、テーブルから投稿データを取ってくる
3. 取ってきた投稿データをviewで繰り返し処理で表示する。

ざっくりいうとこれの中身がどうなっているのかを調べていくことになります。
```
  def search
    @posts = @search_form.search.includes(:user).page(params[:page])
  end
```


## 1.入力フォームで入力された値を受け取り、変数へ格納
### 入力フォーム
入力フォームは以下。本文、コメント、ユーザー名を入力。

app/views/posts/_search.html.slim
```
= form_with model: search_form, url: search_posts_path, scope: :q, class: 'form-inline my-2 my-lg-0 mr-auto', method: :get, local: true do |f|
  = f.search_field :body, class: 'form-control mr-sm-2', placeholder: '本文'
  = f.search_field :comment_body, class: 'form-control mr-sm-2', placeholder: 'コメント'
  = f.search_field :username, class: 'form-control mr-sm-2', placeholder: 'ユーザー名'
```

### ルーティング
送信されると、postコントローラーのsearchアクションに繋がる様にルーティングを設定。
```
  resources :posts, shallow: true do
    collection do
      get :search
    end
```
### searchアクション
入力フォームで入力された値の入った@search_formに対して、seachメソッドを実行。取ってきたデータを@postsに格納。

posts_controller.rb
```
  def search
    @posts = @search_form.search.includes(:user).page(params[:page])
  end
```
後ろの方の解説。includeは、N+1問題をが起きないようにするため。pageメソッドで検索で取得したページネーション対応の全データを取得。
## 2.値が入っている変数に対してseachメソッドを実行し、テーブルから投稿データを取ってくる

### @serch_formについて
SearchPostsFormモデルでnewすると入力したデータを@search_formに格納できます

application_controller
```
  before_action :set_search_posts_form

    # ヘッダー部分（=共通部分）に検索フォームを置くのでApplicationControllerに実装する
  def set_search_posts_form
    @search_form = SearchPostsForm.new(search_post_params)
  end

  def search_post_params
    params.fetch(:q, {}).permit(:body, :comment_body, :username)
  end
```
search_posts_form.rb
```
class SearchPostsForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :body, :string
  attribute :comment_body, :string
  attribute :username, :string

  def search
  ...
  end
```
ActiveModelのModelモジュールを導入しています。これで、テーブルを作成しなくてもActiveRecordの機能が使えるようになります。

ActiveModelのAttributesモジュールを導入すると、attributeメソッドが使えるようになります。

attributeメソッドは、属性名と型を定義することができるメソッドです。今回は、post_content、comment_content、nameをstring型の属性として定義しています。

### searchメソッドについて

search_posts_form.rb
```
  def search
    scope = Post.distinct
    scope = splited_bodies.map { |splited_body| scope.body_contain(splited_body) }.inject { |result, scp| result.or(scp) } if body.present?
    scope = scope.comment_body_contain(body) if comment_body.present?
    scope = scope.username_contain(username) if username.present?
    scope
  end
```
- Post.distinctは全てのポストデータを取ってきて重複するデータを取り除くSQLを発行させる。
```
# 発行されるSQL
SELECT  DISTINCT `posts`.* FROM `posts`
```
次の行からはPostモデルで定義されたscopeを使って、上のSQLに条件部分を足していく。

その前にポストモデルで定義したscopeを確認。

models/post.rb
```
1.  scope :body_contain, ->(word) { where('body LIKE ?', "%#{word}%") }
2.  scope :comment_body_contain, ->(word) { joins(:comments).where('comments.body LIKE ?', "%#{word}%") }
3.  scope :username_contain, ->(word) { joins(:user).where('username LIKE ?', "%#{word}%") }
```
1. 引数のwordをPostテーブルから探す。パターンマッチ演算子。　わかりみSQL 104ページ
2. ポストテーブルにコメントテーブルを結合して、(引数のwordが入っているコメントがある投稿)を探す。
3. ポストテーブルにユーザーテーブルを結合して、(引数のwordが入っているユーザー名がある投稿)を探す。

以上を踏まえた上で、２番目の行の` scope = splited_bodies.map 〜 について
```
scope = splited_bodies.map { |splited_body| scope.body_contain(splited_body) }.inject { |result, scp| result.or(scp) } if body.present?
  ...

  def splited_bodies
    body.strip.split(/[[:blank:]]+/)
  end
```
stripメソッドは文字列の先頭と末尾にある空白を除去した文字列を生成して返してくれるStringクラスのメソッド

splitメソッドとは文字列を分割して配列にするためのメソッド。引数を指定しない場合は空白文字で区切られます。

scope(中身はPost.distinct)に、body_contain(splited_bodies)をくっつけて`Post.distinct.where(content: splited_body)`みたいにする。

result.or(scp)では、条件を足して、`Post.distinct.where(content: '1個目のsplited_body').or(Post.distinct.where(content: '2個目のsplited_body'))`みたいにする。これで空白で区切られた複数の単語で検索できる。

下記もだいたい同じ原理で動きます。
```
scope = scope.comment_body_contain(body) if comment_body.present?
scope = scope.username_contain(username) if username.present?
scope
```
最後にscopeを返します。

### ここで気になった点
comment_body_contain(body)は、なぜcomment_body_contain(comment_body)ではないのかという点。

それからsplited_bodiesメソッドにbodyが変数みたいに使われていた点。 なぜ？

## 3.取ってきた投稿データをviewで繰り返し処理で表示する。

### viewの実装
@postsを繰り返し処理で表示。
app/views/posts/search.html.slim (検索一覧)
```
.container
    .row
        .col-md-8.col-12.offset-md-2
            h2.text-center
                | 検索結果: #{@posts.total_count}件
            = render @posts
```

# 調べた部分
- form_withのヘルパーメソッドについて
- フォームオブジェクト
- ActiveModel
- scope
- injection
- collection

## form_withについて
### model: search_form
格納するインスタンスの指定をしている。(renderされており、元々は@search_formを受け取っている)

_header.html.slim
```
  #navbarTogglerDemo02.collapse.navbar-collapse
   = render 'posts/search_form', search_form: @search_form    
```
### url: search_posts_path"
送信先をpostsコントローラーのsearchアクションにしている

### scope: :q
- 実際のHTML
```
それぞれのname属性が
name="q[body]"
name="q[comment_body]"
name="q[username]
```
spopeオブジェクトに渡した値がname値のプレフィックス(接頭語)になっている

name = "q[name名]"

という形でパラメータが送信されている。

## フォームオブジェクトとは
form_withのmodelオプションにActive Record以外のオブジェクトを渡すデザインパターン
form_withのmodelオプションに渡すオブジェクト自体もform objectと呼ぶ。
DBを使わない検索フォームなどを実装する時に、ActiveRecordを使用したフォームと同じように書くことで可読性が上がる。

## scopeとは
クエリー用のメソッドの連続した部分をまとめて名前をつけ、カスタムのクエリーメソッドとして使うことができる。現場rails178ページ。

## injection
injectメソッドは折りたたみ演算子。eachで+=を使うときの短くかけるバージョン。rubyチェリー４章参照。

## ActiveRecordとは
一言で言えば「RubyとSQLの翻訳機」です。

基本的にDBにはDB言語としてSQLが使われています。
SQLでないとDBの操作ができません。

しかし、RailsにはModelにActiveRecordが適用されているおかげで、Rubyを用いてDBからデータを探したり、持ってきたりすることができます。

どのDBを使用してもRubyで統一できる,Rubyで直感的に書けるなどが利点

## Active Model::Modelとは 
テーブルを作成しなくてもActiveRecordの機能が使えるモジュール。

## include ActiveModel::Attributesとは
データ型を指定できる。

attributeメソッドが使えるようになります。

attributeメソッドは、属性名と型を定義することができるメソッドです。今回は、post_content、comment_content、nameをstring型の属性として定義しています。

## collection
resouceルーティングで、基本の7つ以外のルーティングを設定するときに使う。現場rails p.236

## 個人的なコメント
- アウトプットに1ヶ月ちょっとかかってしまいました。何度も質問しようとしましたが、わからないことが多すぎてどれから質問すればいいかわからず。しょうがないので1つずつ調べていくと、どうやらSQLについて勉強する必要があるらしいとわかったので、わかりみSQLを勉強。勉強していくとSQLだけでなく、Activerecordやscopeについての理解も深まり、わからないことも大体は解決できたので良かったです。わかりみSQLは現在第２部11章テーブル関連について勉強中。rubyチェリーは7章クラス作成についての序盤。現場railsは6章中盤。もう少しがんばります。