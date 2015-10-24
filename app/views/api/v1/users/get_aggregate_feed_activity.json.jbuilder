json.activity(@activities) do |activity|
  json.feed_id activity.feed_id
  json.feed_name activity.feed.try(:name)
  json.feed_color activity.feed.try(:color)
  json.id activity.id
  json.activity_type activity.activity_type
  json.user_id activity.user_id
  json.user_name activity.user.try(:name)
  json.user_phone activity.user.try(:phone_number)
  json.created_at activity.created_at
  json.num_chat_participants activity.num_participants
  json.latest_chat_time activity.latest_comment_time
  
  json.activity_venue activity.venue
  json.added_note activity.feed_venue.try(:description)

  json.venue_comment_id activity.feed_share.try(:venue_comment_id)
  json.venue_comment_created_at activity.feed_share.try(:venue_comment).try(:created_at)
  json.media_type activity.feed_share.try(:venue_comment).try(:media_type)
  json.image_url_1 activity.feed_share.try(:venue_comment).try(:image_url_1)
  json.image_url_2 activity.feed_share.try(:venue_comment).try(:image_url_2)
  json.image_url_3 activity.feed_share.try(:venue_comment).try(:image_url_3)
  json.video_url_1 activity.feed_share.try(:venue_comment).try(:video_url_1)
  json.video_url_2 activity.feed_share.try(:venue_comment).try(:video_url_2)
  json.video_url_3 activity.feed_share.try(:venue_comment).try(:video_url_3)
  json.content_origin activity.feed_share.try(:venue_comment).try(:content_origin)
  json.thirdparty_username activity.feed_share.try(:venue_comment).try(:thirdparty_username)

  json.num_likes activity.num_likes
  json.has_liked @user.likes.where("feed_activity_id = ?", activity.id).any?
  
  json.topic activity.feed_topic.try(:message)
end
json.pagination do 
  json.current_page @activities.current_page
  json.total_pages @activities.total_pages
end