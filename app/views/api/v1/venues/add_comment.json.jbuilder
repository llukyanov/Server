json.id @comment.id
json.comment @comment.comment
json.media_type @comment.media_type
json.media_url @comment.image_url_1
json.user_id @comment.user_id
json.user_name @comment.user.try(:name)
json.username_private @comment.username_private
json.venue_id @comment.venue_id
json.venue_name @comment.venue.try(:name)
json.created_at @comment.created_at
json.updated_at @comment.updated_at

