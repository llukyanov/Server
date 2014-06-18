json.array! @venue.venue_comments do |comment|
  json.id comment.id
  json.comment comment.comment
  json.media_type comment.media_type
  json.media_url comment.media_url
  json.user_id comment.user_id
  json.user_name comment.user.try(:name)
  json.username_private comment.user.try(:username_private)
  json.venue_id comment.venue_id
  json.venue_name comment.venue.try(:name)
  json.viewed comment.is_viewed?(@user)
  json.total_views comment.total_views
  json.created_at comment.created_at
  json.updated_at comment.updated_at
end
