json.array! @feeds do |feed|
	json.id feed.id
	json.name feed.name
	json.open feed.open
	json.created_at feed.created_at
	json.num_users	feed.num_users
	json.num_venues feed.num_venues
	json.num_moments feed.num_moments
	json.feed_color feed.feed_color
	json.users_can_add_places feed.open
	json.creator feed.user
	json.list_description feed.description
end