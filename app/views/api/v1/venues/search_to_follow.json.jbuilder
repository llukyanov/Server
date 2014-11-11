json.array! @venues do |v|
  json.id v.id
  json.name v.name
  json.formatted_address v.address
  json.is_following @user.vfollowing?(v)
  json.color_rating v.color_rating
end
