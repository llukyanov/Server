json.lists(@feeds) do |feed|
	json.id feed.id
	json.name feed.name
	json.created_at feed.created_at
	json.venue_added 1
	json.num_users	feed.num_users
	json.num_venues feed.num_venues
	json.num_moments feed.num_moments
	json.feed_color feed.feed_color
	json.users_can_add_places feed.open
	json.creator feed.user
	json.has_added feed.has_added?(@user)
	json.list_description feed.description
end
json.pagination do 
  json.current_page @feeds.current_page
  json.total_pages @feeds.total_pages
end