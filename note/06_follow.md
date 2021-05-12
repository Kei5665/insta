# 06 フォロー機能を実装
## フォロー機能の概要
- フォロー・アンフォローは非同期で行う。form_withを利用する。
- 適切なバリデーションを付与する
- ログインしている場合フォローしているユーザーと自分の投稿だけ表示させる
- ログインしていない場合全ての投稿を表示させる
- 一件もない場合は『投稿がありません』と画面に表示させる
- 投稿一覧画面右にあるユーザー一覧については登録日が新しい順に5件分表示する
- ユーザー一覧画面、詳細画面も実装する

## フォローリンク
- app/views/users/_follow.html.slim

```
= link_to relationships_path(followed_id: user.id), class: 'btn btn-raised active', method: :post, remote: true do
  | フォロー 
```

- 実際のHTMLでの出力

```
<a class="btn btn-raised btn-outline-warning" data-remote="true" rel="nofollow" data-method="post" href="/relationships?followed_id=17">フォロー</a>
```


href="/relationships?followed_id=17"→このURLを受け取るとどのアクションに振り分けられるのか？
$rake routesで飛び先確認

```
relationships POST   /relationships(.:format)                                                                 relationships#create
```

relationshipsコントローラのcreateアクションに飛びます。

- relationships_controller(クリエイトアクション)

```
  def create
    @user = User.find(params[:followed_id])
    current_user.follow(@user)
  end
```

URLから受け取ったfllowed_idでユーザーを探します。探したユーザーに対してfollowメソッドを行います。
followingを呼び出すと、フォローした（:active_relationships）ユーザー(:followed)一覧を取得できる。そこにユーザーを入れる。これでフォロー完了です。

- model/user.rb

```
  def follow(other_user)
    following << other_user  
  end
```
```
 has_many :following, through: :active_relationships, source: :followed
```

## フォローしたユーザー一覧を取得するためには
- ユーザモデル
```
has many :following,thorough:relationships,source: user
```
前回の課題で出たlike_postsを参考にして書くと、上記のような感じで書けるのではないかと想定しました。
ここで問題なのは、relationshipsテーブルにはfollow_idとfollowed_idのカラムがあります。この記述ではどっちを紐付けるか不明。
なので、どちらと紐づければよいのか判断できるように、参照元の外部キーを指定する。

```
has_many :relationships, foreign_key: 'follower_id'
has many :following,thorough:relationships,source: user
```
また、source: :userでは問題があります。userだけだと、フォローする人とフォローされる人の関係が作れません。これは[【初心者向け】丁寧すぎるRails『アソシエーション』チュートリアル【幾ら何でも】【完璧にわかる】🎸 \- Qiita](https://qiita.com/kazukimatsumoto/items/14bdff681ec5ddac26d1#user%E3%81%A8user%E3%81%AE%E5%A4%9A%E5%AF%BE%E5%A4%9Amn%E3%82%92%E8%A8%AD%E8%A8%88%E3%81%97%E3%82%88%E3%81%86%E8%87%AA%E5%B7%B1%E7%B5%90%E5%90%88)によると自己結合というものが必要らしいということがわかりました。
なのでユーザーを切り分けます。
- relatinshipsモデル
```
  belongs_to :follower, class_name: 'User'
  belongs_to :followed, class_name: 'User'
```
そしてsorce：を :followed（フォローした）に変更します。
```
  has_many :relationships, foreign_key: 'follower_id'
  has_many :following, through: :relationships, source: :followed
```
また、今回の課題では実装していませんでしたが、フォロワーを取得したいときに、このままだと問題が出てきます。
フォロワー一覧を取得するときには
```
has_many :followers, through: :relationships, source: :follower
```
これだとフォローしているユーザー一覧を取得する時のrelationshipsが上書きされて、フォローしている一覧が取得できなくなります。
なので、relationshipsを区別できるようにそれぞれ名前を変える。
```
has_many :passive_relationships, class_name: 'Relationship',
                                   foreign_key: 'followed_id'

has_many :active_relationships, class_name: 'Relationship',
                                  foreign_key: 'follower_id'
```
これでフォローしたユーザーの一覧が取得できます。

## foreign key（個人的なメモ）
親のidを保存するカラム。どの親に所属しているかを識別できる。対義語はprimary Key

## コメント
同一のモデル内でも関連づけができることを学びました。
## 参照リンク
[Active Record の関連付け \- Railsガイド](https://railsguides.jp/association_basics.html#has-many-through%E9%96%A2%E9%80%A3%E4%BB%98%E3%81%91)
[【初心者向け】丁寧すぎるRails『アソシエーション』チュートリアル【幾ら何でも】【完璧にわかる】🎸 \- Qiita](https://qiita.com/kazukimatsumoto/items/14bdff681ec5ddac26d1#user%E3%81%A8user%E3%81%AE%E5%A4%9A%E5%AF%BE%E5%A4%9Amn%E3%82%92%E8%A8%AD%E8%A8%88%E3%81%97%E3%82%88%E3%81%86%E8%87%AA%E5%B7%B1%E7%B5%90%E5%90%88)
[みけたさんの記事](https://github.com/miketa-webprgr/TIL/blob/master/11_Rails_Intensive_Training/06_issue_note_follow-unfollow_association.md)