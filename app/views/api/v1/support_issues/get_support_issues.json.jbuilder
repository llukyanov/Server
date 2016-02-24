json.chat_messages(@issues) do |issue|
  json.support_issue_id issue.id
  json.user_id issue.user_id
  json.user_name issue.user.try(:name)
  json.is_read issue.unread_messages_present?
  json.chat_message issue.support_messages.order("id DESC").first.try(:message)
  json.created_at issue.support_messages.order("id DESC").first.try(:created_at)
end