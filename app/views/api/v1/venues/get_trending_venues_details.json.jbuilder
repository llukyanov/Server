json.cache_collection! @venues, expires_in: 5.minutes do |v|
	json.id v.id
	json.comments v.venue_comments.order("id DESC LIMIT 5")
	json.hashtags v.meta_datas.order("relevance_score DESC LIMIT 5")
end