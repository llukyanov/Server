class VenueComment < ActiveRecord::Base
	#validates :comment, presence: true

	belongs_to :user
	belongs_to :venue
	belongs_to :feed_message
	
	has_many :flagged_comments, :dependent => :destroy
	has_many :comment_views, :dependent => :destroy
	has_many :lumen_values
	has_many :meta_datas, :dependent => :destroy

	validate :comment_or_media


	def comment_or_media
		if self.comment.blank? and self.image_url_1.blank?
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

	def self.convert_instagram_to_vc(instagram, origin_venue, vortex)
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

		if vortex != nil && lytit_venue != nil
			if lytit_venue.distance_from([vortex.latitude, vortex.longitude]) * 1609.34 > 6000
				return nil
			end
		end

		#create a Venue Comment if its creation time is after the latest pull time of its venue (to prevent duplicates)
		if lytit_venue !=nil and (lytit_venue.last_instagram_pull_time == nil || (lytit_venue.last_instagram_pull_time != nil && DateTime.strptime("#{instagram.created_time}",'%s') >= lytit_venue.last_instagram_pull_time ))
			vc = nil
			begin
				image_1 = instagram.images.thumbnail.url rescue nil
				image_2 = instagram.images.low_resolution.url rescue nil
				image_3 = instagram.images.standard_resolution.url rescue nil
				video_1 = instagram.videos.low_bandwith.url rescue nil
				video_2 = instagram.videos.low_resolution.url rescue nil
				video_3 = instagram.videos.standard_resolution.url rescue nil
				if instagram.type == "video"
					vc = VenueComment.create!(:venue_id => lytit_venue.id, :image_url_1 => image_1, :image_url_2 => image_2, :image_url_3 => image_3, :video_url_1 => video_1, :video_url_2 => video_2, :video_url_3 => video_3,:media_type => "video", :content_origin => "instagram", :time_wrapper => DateTime.strptime("#{instagram.created_time}",'%s'), :instagram_id => instagram.id, :thirdparty_username => instagram.user.username)
				else
					vc = VenueComment.create!(:venue_id => lytit_venue.id, :image_url_1 => image_1, :image_url_2 => image_2, :image_url_3 => image_3, :media_type => "image", :content_origin => "instagram", :time_wrapper => DateTime.strptime("#{instagram.created_time}",'%s'), :instagram_id => instagram.id, :thirdparty_username => instagram.user.username)
				end
			rescue
				puts "Oops, uniqueness violation!"
			end
			if vc != nil
				new_media_created = true
				if origin_venue == nil
					lytit_venue.update_columns(last_instagram_pull_time: Time.now-10.minutes)#hackery, to make sure that all instagrams of a venue in pull are not excluded after the first one
				end
				vote = LytitVote.new(:value => 1, :venue_id => lytit_venue.id, :user_id => nil, :venue_rating => lytit_venue.rating ? lytit_venue.rating : 0, 
													:prime => 0.0, :raw_value => 1.0, :time_wrapper => DateTime.strptime("#{instagram.created_time}",'%s'))			
				vote.save
				lytit_venue.update_r_up_votes(vote.time_wrapper)
				lytit_venue.update_columns(latest_posted_comment_time: vote.time_wrapper)
				lytit_venue.delay.update_rating()
				
				if LytSphere.where("venue_id = ?", lytit_venue.id).any? == false
					LytSphere.create_new_sphere(lytit_venue)
				end
				puts "instagram venue comment created"
				lytit_venue.feeds.update_all(new_media_present: true)
				lytit_venue.feeds.update_all(latest_content_time: vc.created_at)
				instagram_tags = instagram.tags
				instagram_captions = instagram.caption.text.split rescue nil
				vc.delay.extract_instagram_meta_data(instagram_tags, instagram_captions)
			end
		end
		return new_media_created

	end

	def extract_instagram_meta_data(instagram_tags, instagram_captions)
		inst_hashtags = instagram_tags
		inst_comment = instagram_captions
		#inst_meta_data = (inst_hashtags << inst_comment).flatten.compact

		if inst_hashtags != nil and inst_hashtags.count != 0
			inst_hashtags.each do |data|
				if data.length > 2 && (data.include?("inst") == false && data.include?("gram") == false && data.include?("like") == false)
					lookup = MetaData.where("meta = ? AND venue_id = ?", data, venue_id).first
					if lookup == nil
						venue_meta_data = MetaData.create!(:venue_id => venue_id, :venue_comment_id => id, :meta => data, :clean_meta => nil) #rescue MetaData.increment_relevance_score(data, venue_id)
					else
						lookup.increment_relevance_score
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
					extra_clean_data = remove_meta_data_prefixes_suffixes(clean_data)
					venue_meta_data = MetaData.create!(:venue_id => venue_id, :venue_comment_id => id, :meta => clean_data, :clean_meta => extra_clean_data) rescue MetaData.increment_relevance_score(data, venue_id)
				end
			end
		end
	end

	def self.meta_search(query, lat, long, sw_lat, sw_long, ne_lat, ne_long)
		#no direct instagram unique hashtag searches such as instagood, instafood, etc. (legal purposes)
		if query[0..2].downcase == "insta"
		  return nil
		end
		query = '%'+query+'%'

		meta_vc_ids = "SELECT venue_comment_id FROM meta_data WHERE LOWER(meta) LIKE '#{query}'"

		#user searching around himself as determined by centered positioning on map screen
		if (sw_lat.to_i == 0 && ne_long.to_i == 0)		  
		  results = VenueComment.joins(:venue).all.order("(ACOS(least(1,COS(RADIANS(#{lat}))*COS(RADIANS(#{long}))*COS(RADIANS(venues.latitude))*COS(RADIANS(venues.longitude))+COS(RADIANS(#{lat}))*SIN(RADIANS(#{long}))*COS(RADIANS(venues.latitude))*SIN(RADIANS(venues.longitude))+SIN(RADIANS(#{lat}))*SIN(RADIANS(venues.latitude))))*3963.1899999999996) ASC").where("venue_comments.id IN (#{meta_vc_ids})").to_a
		#user searching over an area of view
		else
		  results = VenueComment.joins(:venue).where("latitude > ? AND latitude < ? AND longitude > ? AND longitude < ?", sw_lat, ne_lat, sw_long, ne_long).where("venue_comments.id IN (#{meta_vc_ids})").to_a
		end

		return results
	end

	#Making sure that meta results are reasonable relative to the search term. Also we make sure the comment is not older than a day.
	def meta_search_sanity_check(query)
		passed = false
		if (self.created_at + 1.day) >= Time.now
			require 'fuzzystringmatch'
			jarow = FuzzyStringMatch::JaroWinkler.create( :native )
			prefixes = ["anti", "de", "dis", "en", "fore", "in", "im", "ir", "inter", "mid", "mis", "non", "over", "pre", "re", "semi", "sub", "super", "trans", "un", "under"]
			suffixes = ["able", "ible", "al", "ial", "ed", "en", "er", "est", "ful", "ic", "ing", "ion", "tion", "ation", "ition", "ity", "ty", "ive", "ative", "itive", "less", "ly", "ment", "ness", "ous", "eous", "ious", "y"]      

			for entry in self.meta_datas
				raw_jarow_distance = p jarow.getDistance(entry.meta, query)
				if entry.clean_meta != nil
					clean_jarow_distance = p jarow.getDistance(entry.clean_meta, query)
					clean_meta_length = entry.clean_meta.length
				else
					implicit_clean_meta = self.remove_meta_data_prefixes_suffixes(entry.meta)
					clean_jarow_distance = p jarow.getDistance(implicit_clean_meta, query)
					clean_meta_length = implicit_clean_meta.length
				end
				#we compare lengths because search results and meta data should have equal (or close to) roots
				if raw_jarow_distance > 0.9 || (clean_jarow_distance > 0.7 && clean_meta_length < query.length*2)
					passed = true
					break
				end	
			end	

		end
		return passed
	end 

	def remove_meta_data_prefixes_suffixes(data)
		prefixes = ["anti", "de", "dis", "en", "fore", "in", "im", "ir", "inter", "mid", "mis", "non", "over", "pre", "re", "semi", "sub", "super", "trans", "un", "under"]
		suffixes = ["able", "ible", "al", "ial", "ed", "en", "er", "est", "ful", "ic", "ing", "ion", "tion", "ation", "ition", "ity", "ty", "ive", "ative", "itive", "less", "ly", "ment", "ness", "ous", "eous", "ious", "y"]		  
		
		no_prefix_suffix_data = nil
		if data.length > 5
			for prefix in prefixes
				no_prefix_data = data
				prefix_len = prefix.length
				data_len = data.length

				if data_len > prefix_len and data[0..prefix_len-1] == prefix
					no_prefix_data = data[(prefix_len)..data_len+1]
					break
				end
			end

			if no_prefix_data.length > 6
				for suffix in suffixes
					suffix_len = suffix.length
					no_prefix_data_len = no_prefix_data.length
					no_prefix_suffix_data = no_prefix_data

					if no_prefix_data_len > suffix_len and no_prefix_data[(no_prefix_data_len-suffix_len)..no_prefix_data_len] == suffix
						no_prefix_suffix_data = no_prefix_data[0..(no_prefix_data_len-suffix_len)-1]
						break
					end
				end
			else
				clean_data = no_prefix_data
			end

			if no_prefix_suffix_data != nil
				clean_data = no_prefix_suffix_data
			end

		else
			clean_data = data
		end					
		return clean_data
	end

	def self.twitter_test
		client = Twitter::REST::Client.new do |config|
		  config.consumer_key        = '286I5Eu8LD64ApZyIZyftpXW2'
		  config.consumer_secret     = '4bdQzIWp18JuHGcKJkTKSl4Oq440ETA636ox7f5oT0eqnSKxBv'
		  config.access_token        = '2846465294-QPuUihpQp5FjOPlKAYanUBgRXhe3EWAUJMqLw0q'
		  config.access_token_secret = 'mjYo0LoUnbKT4XYhyNfgH4n0xlr2GCoxBZzYyTPfuPGwk'
		end
		
		client.search("new york", result_type: "recent", geo_code: "40.733482,-73.992367,0.5mi").take(3).collect do |tweet|
		  "#{tweet.user.screen_name}: #{tweet.text} / #{tweet.created_at} //// #{tweet.user.profile_image_url}"
		end

		return client.search("new york", result_type: "recent", geo_code: "40.733482,-73.992367,0.5mi", since: "#{Time.now.strftime("%Y-%d-%m")}").take(10).collect
	end
			
end




