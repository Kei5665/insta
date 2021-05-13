class SearchPostsForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :body, :string
  attribute :comment_body, :string

  def search
    scope = Post.distinct
    scope = scope.body_contain(body) if body.present?
    scope
  end
end