json.chat_messages(@messages) do |message|
  json.id message.id
  json.user_id message.user_id
  json.user_name message.user.try(:name)
  json.user_phone message.user.try(:phone_number)
  json.chat_message message.message
  json.venue_comment_id message.venue_comment.try(:id)
  json.media_type message.venue_comment.try(:media_type)
  json.media_url message.venue_comment.try(:image_url_2)
  json.timestamp message.created_at
  json.did_like message.did_like?(@user)
  json.num_likes message.
end

json.pagination do 
  json.current_page @messages.current_page
  json.total_pages @messages.total_pages
end