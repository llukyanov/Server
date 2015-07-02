class VenueComment < ActiveRecord::Base
	#validates :comment, presence: true

	belongs_to :user
	belongs_to :venue
	
	has_many :flagged_comments, :dependent => :destroy
	has_many :comment_views, :dependent => :destroy
	has_many :lumen_values
	has_many :meta_datas, :dependent => :destroy

	validate :comment_or_media


	def comment_or_media
		if self.comment.blank? and self.media_url.blank?
			errors.add(:comment, 'or image is required')
		end
	end

	def username_for_trending_venue_view
		if self.content_origin == "instagram"
			self.thirdparty_username
		else
			self.user.name
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
				consider = 0
			end
		end
		update_columns(consider: consider)
		return consider
	end

	def self.get_comments_for_cluster(venue_ids)
		VenueComment.where("venue_id IN (?) AND (NOW() - created_at) <= INTERVAL '1 DAY'", venue_ids).includes(:venue).order("time_wrapper desc")
	end

	def self.convert_instagram_to_vc(instagram, origin_venue)
		place_name = instagram.location.name
		place_id = instagram.location.id
		lat = instagram.location.latitude
		long = instagram.location.longitude

		new_media_created = false

		if origin_venue == nil
			if Venue.name_is_proper?(place_name) == true
				lytit_venue = Venue.fetch_venues_for_instagram_pull(place_name, lat, long, place_id)	
			else
				return nil
			end
		else
			lytit_venue = origin_venue
		end

		#create a Venue Comment if its creation time is after the latest pull time of its venue (to prevent duplicates)
		if lytit_venue.last_instagram_pull_time == nil || (lytit_venue.last_instagram_pull_time != nil && DateTime.strptime("#{instagram.created_time}",'%s') >= lytit_venue.last_instagram_pull_time )
			if not VenueComment.where("instagram_id = ?", instagram.id).any?
				vc = VenueComment.new(:venue_id => lytit_venue.id, :media_url => instagram.images.standard_resolution.url, :media_type => "image", :content_origin => "instagram", :time_wrapper => DateTime.strptime("#{instagram.created_time}",'%s'), :instagram_id => instagram.id, :thirdparty_username => instagram.user.username)
				if vc.save
					new_media_created = true
					if origin_venue == nil
						lytit_venue.update_columns(last_instagram_pull_time: Time.now-10.minutes)#hackery, to make sure that all instagrams of a venue in pull are not excluded after the first one
					end
					vote = LytitVote.new(:value => 1, :venue_id => lytit_venue.id, :user_id => nil, :venue_rating => lytit_venue.rating ? lytit_venue.rating : 0, 
														:prime => 0.0, :raw_value => 1.0, :time_wrapper => DateTime.strptime("#{instagram.created_time}",'%s'))			
					vote.save
					lytit_venue.update_r_up_votes(vote.time_wrapper)
					lytit_venue.update_columns(latest_posted_comment_time: vote.time_wrapper)
					
					if LytSphere.where("venue_id = ?", lytit_venue.id).any? == false
						LytSphere.create_new_sphere(lytit_venue)
					end
					puts "instagram venue comment created"
					lytit_venue.feeds.update_all(new_media_present: true)
					instagram_tags = instagram.tags
					instagram_captions = instagram.caption.text.split rescue nil
					vc.includes(:meta_datas).delay.extract_instagram_meta_data(instagram_tags, instagram_captions)
				end
			end
		end
		return new_media_created

	end

	def extract_instagram_meta_data(instagram_tags, instagram_captions)
		inst_hashtags = instagram_tags
		inst_comment = instagram_captions
		#inst_meta_data = (inst_hashtags << inst_comment).flatten.compact

		junk_words = ["the", "their", "there", "yes", "you", "are", "when", "why", "what", "lets", "this", "got", "put", "such", "much", "ask", "with", "where", "each", "all", "from", "bad", "not", "for", "our"]

		if inst_hashtags != nil and inst_hashtags.count != 0
			inst_hashtags.each do |data|
				#sub_entries are for CamelCase handling if any
				sub_entries = data.split /(?=[A-Z])/
				sub_entries.each do |sub_entry|
					clean_data = sub_entry.downcase.gsub(/[^0-9A-Za-z]/, '')
					puts "Dirty Data: #{sub_entry}...Clean Data: #{clean_data}"
					if clean_data.length>2 && junk_words.include?(clean_data) == false
						if MetaData.where("venue_id = ? and meta = ?", venue_id, clean_data).any? == false	
							venue_meta_data = MetaData.new(:venue_id => venue_id, :venue_comment_id => id, :meta => clean_data)
							venue_meta_data.save
						end
					end
				end
			end
		end

		if inst_comment != nil and inst_comment.count != 0
			inst_comment.each do |data|
				#sub_entries are for CamelCase handling if any
				sub_entries = data.split /(?=[A-Z])/
				sub_entries.each do |sub_entry|
					clean_data = sub_entry.downcase.gsub(/[^0-9A-Za-z]/, '')
					puts "Dirty Data: #{sub_entry}...Clean Data: #{clean_data}"
					if clean_data.length>2 && junk_words.include?(clean_data) == false
						if MetaData.where("venue_id = ? and meta = ?", venue_id, clean_data).any? == false	
							venue_meta_data = MetaData.new(:venue_id => venue_id, :venue_comment_id => id, :meta => clean_data)
							venue_meta_data.save
						end
					end
				end
			end
		end
	end


	def extract_venue_comment_meta_data
		text = self.comment.split rescue nil
		junk_words = ["the", "their", "there", "yes", "you", "are", "when", "why", "what", "lets", "this", "got", "put", "such", "much", "ask", "with", "where", "each", "all", "from", "bad", "not", "for", "our"]

		text.each do |data|
			#sub_entries are for CamelCase handling if any
			sub_entries = data.split /(?=[A-Z])/
			sub_entries.each do |sub_entry|
				clean_data = sub_entry.downcase.gsub(/[^0-9A-Za-z]/, '')
				puts "Dirty Data: #{sub_entry}...Clean Data: #{clean_data}"
				if clean_data.length>2 && junk_words.include?(clean_data) == false
					if MetaData.where("venue_id = ? and meta = ?", venue_id, clean_data).any? == false	
						venue_meta_data = MetaData.new(:venue_id => venue_id, :venue_comment_id => id, :meta => clean_data)
						venue_meta_data.save
					end
				end
			end
		end
	end
			
end




