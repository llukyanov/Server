json.array! @top_users do |top_user|
	json.id top_user.id
	json.name top_user.name
	json.created_at top_user.created_at
	json.updated_at top_user.updated_at
	json.is_following @user.following?(top_user)
	json.followers_count top_user.followers.count
	json.following_count (top_user.followed_users.count + top_user.followed_venues.count)
	json.media_url (top_user.last_media_comment).try(:media_url)
	json.media_type (top_user.last_media_comment).try(:media_type)
end