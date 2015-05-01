class VenueComment < ActiveRecord::Base
	#validates :comment, presence: true

	belongs_to :user
	belongs_to :venue
	belongs_to :bounty
	
	has_many :flagged_comments, :dependent => :destroy
	has_many :comment_views, :dependent => :destroy
	has_many :lumen_values

	validate :comment_or_media
	validate :proper_media_type_for_response



	def comment_or_media
		if self.comment.blank? and self.media_url.blank?
			errors.add(:comment, 'or image is required')
		end
	end

	def proper_media_type_for_response
		if bounty_id != nil
			if self.media_type != self.bounty.media_type
				errors.add(:media_type, 'does not match Moment Request. Please try again.')
			end
		end
	end

	def is_viewed?(user)
		CommentView.find_by_user_id_and_venue_comment_id(user.id, self.id).present?
	end

	def total_views
		CommentView.where(venue_comment_id: self.id).count
	end

	def populate_total_views
		update_columns(views: total_views)
	end

	def update_views
		current = self.views
		update_columns(views: (current + 1))
	end

	def total_adj_views
		self.adj_views
	end

	def calculate_adj_view
		time = Time.now
		comment_time = self.created_at
		time_delta = ((time - comment_time) / 1.minute) / (LumenConstants.views_halflife)
		adjusted_view = 2.0 ** (-time_delta)

		previous = self.adj_views
		update_columns(adj_views: (adjusted_view + previous).round(4))
	end

	#We need to omit CommentViews generated by the user of the VenueComment
	def populate_adj_views
		total = 0
		if self.media_type == 'text'
			total = 1
		else
			views = CommentView.where("venue_comment_id = ? and user_id != ?", self.id, self.user_id)
			views.each {|view| total += 2 ** ((- (view.created_at - self.created_at) / 1.minute) / (LumenConstants.views_halflife))}
		end
		update_columns(adj_views: total.round(4))
		total
	end

	#determines weight of venue comment for Lumen calculation
	def weight
		type = self.media_type

		if type == "text"
			LumenConstants.text_media_weight
		elsif type == "image"
			LumenConstants.image_media_weight
		else
			LumenConstants.video_media_weight
		end

	end

	def VenueComment.live_from_venues_followed_by(user)
		followed_venues_ids = "SELECT vfollowed_id FROM venue_relationships WHERE ufollower_id = #{user.id}"
		where("venue_id IN (#{followed_venues_ids}) AND user_id IS NOT NULL AND (NOW() - created_at) <= INTERVAL '1 DAY' ").order("id desc")
	end

	def set_offset_created_at
		#note that offset time will still be stored in UTC, disregard the timezone
		if venue != nil
			offset = created_at.in_time_zone(venue.time_zone).utc_offset
			offset_time = created_at + offset
			update_columns(offset_created_at: offset_time)
		end
	end

	def consider?
		consider = 1
		previous_comment = user.venue_comments.order("created_at desc limit 2")[1]

		if previous_comment == nil
			update_columns(consider: consider)
			return consider
		else
			if (self.venue_id == previous_comment.venue_id) && ((self.created_at - previous_comment.created_at) >= (LumenConstants.posting_pause*60))
				consider = 1
			elsif self.venue_id != previous_comment.venue_id
				consider = 1
			else
				if previous_comment.user_id == nil#it was a bounty request or response
					consider = 1
				else
					consider = 0
				end
			end
		end
		update_columns(consider: consider)
		return consider
	end

	#Bounty Responses Methods ----------------------------------------------------------------------------------------
	def response_index
		bounty.venue_comments.order("id desc").index(self)+1
	end

	def response_page_in_view
		pagination_per_page = 12
		return self.response_index/pagination_per_page+1
	end

	def claim_acceptance
		self.is_response_accepted = true
		save
		
		VenueComment.where("bounty_id = #{self.bounty_id} AND id != #{self.id}").update_all(is_response_accepted: false)

		reward = bounty.lumen_reward
		bounty_lumen_value = LumenValue.new(:value => (reward-0.1), :user_id => user.id, :bounty_id => bounty.id)
		user.bounty_lumens = (user.bounty_lumens + (reward-0.1)).round(4)
		user.lumens = (user.lumens + (reward-0.1)).round(4) #0.1 is given back to the bounty issuer as a sign of good faith for accepting
		user.save
		bounty_lumen_value.save

		bounty_issuer = self.bounty.user
		bounty_lumen_value_2 = LumenValue.new(:value => 0.1, :user_id => bounty_issuer.id, :media_type => "bonus")
		bounty_issuer.lumens = bounty_issuer.lumens + (0.1)
		bounty_issuer.save
		bounty_lumen_value_2.save

		if bounty.decrement_venue_bounty_count == true
			if self.venue.outstanding_bounties >= 1
				self.venue.decrement!(:outstanding_bounties, 1)
			end
			bounty.decrement_venue_bounty_count = false
			bounty.validity = false
			bounty.save
		end
		self.bounty_claim_acceptance_notification
	end

	def claim_rejection(reasoning)
		self.is_response_accepted = false
		self.rejection_reason = reasoning
		save

		bounty.decrement!(:num_responses, 1)
		
		new_rejection_entry = BountyClaimRejectionTracker.new(:user_id => user_id, :venue_comment_id => self.id)
		new_rejection_entry.save

		user.latest_rejection_time = Time.now
		user.save

		self.bounty_claim_rejection_notification
	end

	def status
		if is_response_accepted == false
			return 0
		elsif is_response_accepted == true
			return 2
		else
			return 1
		end
	end

	#Venue Comments can be just Venue Comments (0), Bounties (1), or Bounty Responses(2)
	def type
		if bounty_id == nil
			0
		elsif bounty_id != nil && user_id == nil
			1
		else
			2
		end
	end

	#Bounty Response Notifications
	def send_bounty_claim_notification
		recipient_ids = BountySubscriber.where("bounty_id = #{self.bounty_id}").pluck(:user_id)
		for recipient_id in recipient_ids
			payload = {
					:object_id => self.id, 
					:type => 'bounty_claim', 
					:user_id => recipient_id 
			}
			if bounty.user_id == recipient_id
				message = "Someone responded to your Request at #{bounty.venue.name}"
			else
				message = "Someone responded to the Request at #{bounty.venue.name}"
			end
			notification = self.store_new_bounty_claim_notification(payload, User.find_by_id(recipient_id), message)
			payload[:notification_id] = notification.id

			if bounty.user.push_token
				count = Notification.where(user_id: user_id, read: false, deleted: false).count
				APNS.delay.send_notification(bounty.user.push_token, { :priority =>10, :alert => message, :content_available => 1, :other => payload, :badge => count})
			end

			if bounty.user.gcm_token
				gcm_payload = payload.dup
				gcm_payload[:message] = message
				options = {
					:data => gcm_payload
				}
				request = HiGCM::Sender.new(ENV['GCM_API_KEY'])
				request.send([bounty.user.gcm_token], options)
			end
		end
	end

	def store_new_bounty_claim_notification(payload, recipient, message)
		notification = {
			:payload => payload,
			:gcm => recipient.gcm_token.present?,
			:apns => recipient.push_token.present?,
			:response => notification_payload,
			:user_id => recipient.id,
			:read => false,
			:message => message,
			:deleted => false
		}
		Notification.create(notification)
	end

	def notification_payload
		{
			:bounty => {
			:id => self.bounty_id,
			}
		}
	end

#Bounty Response Acceptance Notification 
	def bounty_claim_acceptance_notification
		self.delay.send_bounty_claim_acceptance_notification
	end

	def send_bounty_claim_acceptance_notification
		payload = {
				:object_id => bounty_id,
				:type => 'bounty_claim_acceptance', 
				:user_id => user_id
		}
		message = "Congratulations! Your Moment Response at #{bounty.venue.name} has been accepted"
		notification = self.store_new_bounty_claim_acceptance_notification(payload, user, message)
		payload[:notification_id] = notification.id

		if bounty.user.push_token
			count = Notification.where(user_id: user_id, read: false, deleted: false).count
			APNS.delay.send_notification(user.push_token, { :priority =>10, :alert => message, :content_available => 1, :other => payload, :badge => count})
		end

		if bounty.user.gcm_token
			gcm_payload = payload.dup
			gcm_payload[:message] = message
			options = {
				:data => gcm_payload
			}
			request = HiGCM::Sender.new(ENV['GCM_API_KEY'])
			request.send([user.gcm_token], options)
		end
	end

	def store_new_bounty_claim_acceptance_notification(payload, user, message)
		notification = {
			:payload => payload,
			:gcm => user.gcm_token.present?,
			:apns => user.push_token.present?,
			:response => acceptance_notification_payload,
			:user_id => user.id,
			:read => false,
			:message => message,
			:deleted => false
		}
		Notification.create(notification)
	end

	def acceptance_notification_payload
		{
			:bounty => {
			:id => self.bounty_id,
			:lumen_reward => (self.bounty.lumen_reward)*0.9,
			:venue_comment_id => self.id,
			:venue_name => self.venue.name
			}
		}
	end

#Bounty Response Rejection Notification
	def bounty_claim_rejection_notification
		self.delay.send_bounty_claim_rejection_notification
	end

	def send_bounty_claim_rejection_notification
		payload = {
		    :object_id => self.id,
		    :type => 'bounty_claim_rejection', 
		    :user_id => user_id
		}
		message = "Your Bounty Claim at #{bounty.venue.name} has been rejected"
		notification = self.store_new_bounty_claim_rejection_notification(payload, user, message)
		payload[:notification_id] = notification.id

		if bounty.user.push_token
		  count = Notification.where(user_id: user_id, read: false, deleted: false).count
		  APNS.delay.send_notification(user.push_token, { :priority =>10, :alert => message, :content_available => 1, :other => payload, :badge => count})
		end

		if bounty.user.gcm_token
		  gcm_payload = payload.dup
		  gcm_payload[:message] = message
		  options = {
		    :data => gcm_payload
		  }
		  request = HiGCM::Sender.new(ENV['GCM_API_KEY'])
		  request.send([user.gcm_token], options)
		end
	end

	def store_new_bounty_claim_rejection_notification(payload, user, message)
		notification = {
		  :payload => payload,
		  :gcm => user.gcm_token.present?,
		  :apns => user.push_token.present?,
		  :response => rejection_notification_payload,
		  :user_id => user.id,
		  :read => false,
		  :message => message,
		  :deleted => false
		}
		Notification.create(notification)
	end

	def rejection_notification_payload
	  {
    	:bounty => {
			:id => self.bounty_id,
			:reason => self.rejection_reason,
			:venue_name => self.venue.name,
			:venue_comment_id => self.id
		}
	  }
	end	


end




