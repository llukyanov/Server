json.array! @users do |user|
	json.id user.id
	json.name user.name
	json.phone_number user.phone_number
	json.fb_id user.facebook_id
	json.num_lists	user.num_lists
	json.num_stars user.num_likes
end