puts 'Start inserting seed "posts" ...'
User.limit(10).each do |user|
  post = user.posts.create({ : Faker::Hacker.say_something_smart, images: [open("#{Rails.root}/db/fixtures/dummy.png")]})
  puts "post#{post.id} has created!"
end