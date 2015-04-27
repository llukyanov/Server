class Bounty < ActiveRecord::Base
	belongs_to :user
	belongs_to :venue

	has_many :venue_comments
	has_many :bounty_subscribers

	def check_validity
		result = true

		if self.expiration.to_time < Time.now and self.validity == true
			if self.decrement_venue_bounty_count == true
				self.venue.decrement!(:outstanding_bounties, 1)
				self.decrement_venue_bounty_count = false
				self.save
			end

			if self.num_responses == 0 || (self.created_at < (Time.now - 1.day)) #If no responses then dismiss bounty. If there are responses then keep valid 24hours after creation.
				self.validity = false
				result = false
				self.save
			end

			if self.num_responses == 0 && self.lumen_reward > 0.0#if no responses received we return the deposited lumens for the request back to the user
				user_lumens = user.lumens 
				user.update_columns(lumens: user_lumens+self.lumen_reward)
				self.update_columns(lumen_reward: 0.0)
			end

		end
		return result
	end

	def total_pages_in_view
		(self.venue_comments-1)/12+1
	end

	def viewed_claim
		self.last_viewed_claim_time = Time.now
		save
	end

	def new_claims
		if self.last_viewed_claim_time == nil
			return self.venue_comments.where("user_id IS NOT NULL").count
		else
			return self.venue_comments.where("user_id IS NOT NULL AND created_at > ?", self.last_viewed_claim_time).count
		end
	end

	def minutes_left
		(self.expiration - Time.now)
	end

	def total_valid_claims
		claims_count = self.venue_comments.where("user_id IS NOT NULL AND (is_response_accepted = TRUE OR is_response_accepted IS NULL)").count
	end

	def is_subscribed?(target_user)
		BountySubscriber.where("bounty_id = ? and user_id = ?", self.id, target_user.id).count > 0 ? true : false
	end

	def num_subscribed
		self.bounty_subscribers.count
	end

	def can_user_respond?(city, state, country, lat, long)
		#location_details = [city, state, country, lat, long]
		venue_type = self.venue.type
		if venue_type == "country" && country == self.venue.country
			result = true
		elsif venue_type == "state" && state == self.venue.state
			result = true
		elsif venue_type == "city" && (city == self.venue.city && state == self.venue.state)
			result = true
		elsif venue_type == "establishment" && (self.venue.distance_to([lat, long]) * 1609.34) <= 400 #meters
			result = true
		else
			result = false
		end

		return result

	end

end