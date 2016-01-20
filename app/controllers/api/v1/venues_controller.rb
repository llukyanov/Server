class Api::V1::VenuesController < ApiBaseController

	skip_before_filter :set_user, only: [:search, :index]

	def show
		@user = User.find_by_authentication_token(params[:auth_token])
		@venue = Venue.find(params[:id])		
		venue = @venue.as_json(include: :venue_messages)

		venue[:compare_type] = @venue.type

		render json: venue
	end

	def get_menue
		@venue = Venue.find(params[:id])
	end

	def delete_comment
		vc = VenueComment.find_by_id(params[:id])
		vc.destroy
		render json: { success: true }
	end

	def report_comment
		if FlaggedComment.where("user_id = ? AND venue_comment_id = ? AND message = ?", @user.id, params[:comment_id], params[:message]).any? == false
			venue_comment = VenueComment.find(params[:comment_id])
			fc = FlaggedComment.new
			fc.user_id = @user.id
			fc.message = params[:message]
			fc.venue_comment_id = venue_comment.id
			fc.save
			render json: fc
		end
	end

	def venue_primer
		venue_id = params[:venue_id]
		
		#venue lookup if needed
		if venue_id.nil?
			if params[:instagram_location_id] != nil
				@venue = Venue.fetch_venues_for_instagram_pull(params[:name], params[:latitude], params[:longitude], params[:instagram_location_id], nil)
				venue_id = @venue.id
			else
				venue_id = nil
			end
		end

		if venue_id.present?
			#prime comments
			comments_cache_key = "venue/#{venue_id}/comments/page#1"
			@comments = Rails.cache.fetch(comments_cache_key, :expires_in => 10.minutes) do
				Venue.get_comments([venue_id]).limit(10)
			end
			@venue = Venue.find_by_id(venue_id)

			#prime tweets
			tweets_cache_key = "venue/#{venue_id}/tweets/page#1"
			@tweets = Rails.cache.fetch(tweets_cache_key, :expires_in => 10.minutes) do
				@venue.venue_twitter_tweets.limit(10)
			end
			render json: { success: true }
		else
			render json: { success: false }
		end
	end

	def cluster_primer
		venue_ids = params[:cluster_venue_ids].split(',').map(&:to_i)
		render json: { success: true }
	end

	def get_comments
		#register feed open
		@user = User.find_by_authentication_token(params[:auth_token])
		
		venue_ids = params[:cluster_venue_ids].split(',').map(&:to_i)

		if not venue_ids 
			render json: { error: { code: ERROR_NOT_FOUND, messages: ["Venue(s) not found"] } }, :status => :not_found
		else
			if venue_ids.count == 1
				@venue = Venue.find_by_id(venue_ids.first)
				if params[:meta_query] != nil
					@comments = VenueComment.meta_search_results(@venue.id, params[:meta_query]).page(params[:page]).per(10)					
				else		
					@venue.delay.account_page_view
					cache_key = "venue/#{venue_ids.first}/comments/page#{params[:page]}"
				end
			else
				cache_key = "cluster/cluster_#{venue_ids.length}_#{params[:cluster_latitude]},#{params[:cluster_longitude]}/comments/page#{params[:page]}"
			end

			if params[:meta_query] == nil
				@view_cache_key = cache_key+"view"
				@comments = Rails.cache.fetch(cache_key, :expires_in => 10.minutes) do
					Venue.get_comments(venue_ids).limit(10).offset((params[:page].to_i-1)*10)
				end

				if venue_ids.count > 1 or @comments.first.is_a?(Hash) == false
					render 'pure_comments.json.jbuilder'
				else
					render 'get_comments.json.jbuilder'
				end
			else
				render 'meta_search_comments.json.jbuilder'
			end
		end
	end

	def get_comments_implicitly
		if params[:country] != nil
			@venue = Venue.fetch(params[:name], params[:formatted_address], params[:city], params[:state], params[:country], params[:postal_code], params[:phone_number], params[:latitude], params[:longitude])
			#Venue.fetch(params["name"], params["formatted_address"], params["city"], params["state"], params["country"], params["postal_code"], params["phone_number"], params["latitude"], params["longitude"])
		else
			@venue = Venue.fetch_venues_for_instagram_pull(params[:name], params[:latitude].to_f, params[:longitude].to_f, params[:instagram_location_id], nil)
		end

		if @venue.instagram_location_id == nil
			initial_instagrams = @venue.set_instagram_location_id(100)
			@venue.delay.account_page_view
		end

		cache_key = "venue/#{@venue.id}/comments/page#{params[:page]}"

		if initial_instagrams != nil
			@comments = Rails.cache.fetch(cache_key, :expires_in => 10.minutes) do					
				venue_comments = Kaminari.paginate_array(initial_instagrams).page(params[:page]).per(10)
				Kaminari::PaginatableArray.new(venue_comments.to_a, limit: venue_comments.limit_value, offset: venue_comments.offset_value, total_count: venue_comments.total_count)
			end
		else
			puts "Making a Get Comments Call because no initial instagrams present!"
			@comments = Rails.cache.fetch(cache_key, :expires_in => 10.minutes) do
				venue_comments = Venue.get_comments([@venue.id]).page(params[:page]).per(10)
				Kaminari::PaginatableArray.new(venue_comments.to_a, limit: venue_comments.limit_value, offset: venue_comments.offset_value, total_count: venue_comments.total_count)
			end
		end

		@view_cache_key = cache_key+"view"
		#@comments = live_comments.page(params[:page]).per(10)
	end

	def get_venue_feeds
		@user = User.find_by_authentication_token(params[:auth_token])
		@feeds = Feed.feeds_in_venue(params[:venue_id])
	end

	def get_cluster_feeds
		@user = User.find_by_authentication_token(params[:auth_token])
		@feeds = Feed.feeds_in_cluster(params[:cluster_venue_ids]).page(params[:page]).per(10)
	end

	def get_tweets
		venue_ids = params[:cluster_venue_ids].split(',')
		cluster_lat = params[:cluster_latitude]
		cluster_long =  params[:cluster_longitude]
		zoom_level = params[:zoom_level]
		map_scale = params[:map_scale]

		
		if venue_ids.count == 1
			@venue = Venue.find_by_id(venue_ids.first)		
			cache_key = "venue/#{venue_ids.first}/tweets/page#{params[:page]}"
			
			#venue_tweets = @venue.venue_twitter_tweets
			#@tweets = venue_tweets.page(params[:page]).per(10)
		else
			cache_key = "cluster/cluster_#{venue_ids.length}_#{params[:cluster_latitude]},#{params[:cluster_longitude]}/tweets/page#{params[:page]}"	
			#cluster_tweets = Venue.cluster_twitter_tweets(cluster_lat, cluster_long, zoom_level, map_scale, params[:cluster_venue_ids])
			#@tweets = cluster_tweets.page(params[:page]).per(10)
		end

		@tweets = Rails.cache.fetch(cache_key, :expires_in => 3.minutes) do
			if venue_ids.count == 1
				@venue.venue_twitter_tweets.limit(10).offset((params[:page].to_i-1)*10)
			else
				Venue.cluster_twitter_tweets(cluster_lat, cluster_long, zoom_level, map_scale, params[:cluster_venue_ids]).offset((params[:page].to_i-1)*10)
			end
		end

	end

	def get_surrounding_tweets
		venue_ids = params[:cluster_venue_ids].split(',')
		lat = params[:cluster_latitude]
		long =  params[:cluster_longitude]
		zoom_level = params[:zoom_level]
		map_scale = params[:map_scale]
		fresh_pull = params[:fresh_pull]

		@user = User.find_by_authentication_token(params[:auth_token])

		if fresh_pull == "0"
			surrounding_tweets = Rails.cache.fetch("surrounding_tweets/#{@user.id}", :expires_in => 5.minutes) do
				Venue.surrounding_twitter_tweets(lat, long, params[:cluster_venue_ids])
			end
		else
			begin
				Rails.cache.delete("surrounding_tweets/#{@user.id}")
			rescue
				puts "No cache present to delete"
			end
			surrounding_tweets = Venue.surrounding_twitter_tweets(lat, long, params[:cluster_venue_ids])
		end
		
		@tweets = Kaminari.paginate_array(surrounding_tweets).page(params[:page]).per(10)
	end

	def mark_comment_as_viewed
		@user = User.find_by_authentication_token(params[:auth_token])
		@comment = VenueComment.find_by_id(params[:post_id])

		#consider is used for Lumen calculation. Initially it is set to 2 for comments with no views and then is
		#updated to the true value (1 or 0) for a particular comment after a view (comments with no views aren't considered
		#for Lumen calcuation by default)

		if (@comment.is_viewed?(@user) == false) #and (@comment.user_id != @user.id)
			@comment.update_views
			poster = @comment.user
			if poster != nil
				poster.update_total_views
				if poster.id != @user.id
					@comment.calculate_adj_view
					if @comment.consider? == 1 
						poster.update_lumens_after_view(@comment)
					end
				end
			end
		end

		if @comment.present?
				comment_view = CommentView.new
				comment_view.user = @user
				comment_view.venue_comment = @comment
				comment_view.save
		else
			render json: { error: { code: ERROR_NOT_FOUND, messages: ["Venue / Post not found"] } }, :status => :not_found
			return
		end
	end

	def refresh_map_view
		Venue.delay.instagram_content_pull(params[:latitude], params[:longitude])
		cache_key = "lyt_map"
		@view_cache_key = cache_key+"/view"
		@venues = Rails.cache.fetch(cache_key, :expires_in => 5.minutes) do
			Venue.where("color_rating > -1.0 OR is_live IS TRUE")
		end
		render 'display.json.jbuilder'
	end

	def refresh_map_view_by_parts_v_old
		lat = params[:latitude] || 40.741140
		long = params[:longitude] || -73.981917

		if params[:page].to_i == 1
			num_page_entries = 500
		else
			num_page_entries = 1000
		end

		cache_key = "lyt_map_by_parts"
		venues = Rails.cache.fetch(cache_key, :expires_in => 5.minutes) do
			Venue.where("color_rating > -1.0 OR is_live IS TRUE")
		end

		ordered_venues = venues.order("(ACOS(least(1,COS(RADIANS(#{lat}))*COS(RADIANS(#{long}))*COS(RADIANS(venues.latitude))*COS(RADIANS(venues.longitude))+COS(RADIANS(#{lat}))*SIN(RADIANS(#{long}))*COS(RADIANS(venues.latitude))*SIN(RADIANS(venues.longitude))+SIN(RADIANS(#{lat}))*SIN(RADIANS(venues.latitude))))*6376.77271) ASC")
		user_city = ordered_venues.first.city || ordered_venues[1].city || ordered_venues[2].city || ordered_venues[3].city || ordered_venues[4].city
		@view_cache_key = cache_key+"/#{user_city}/part_"+params[:page]

		@venues = ordered_venues.page(params[:page]).per(num_page_entries)
		render 'display_by_parts.json.jbuilder'
	end

	def refresh_map_view_by_parts
		lat = params[:latitude] || 40.741140
		long = params[:longitude] || -73.981917
		center_point = [lat, long]
		proximity_box = Geokit::Bounds.from_point_and_radius(center_point, 2, :units => :kms)
				
		if params[:page].to_i == 1
			num_page_entries = 500
		else
			num_page_entries = 750
		end

=begin		
		lit_venues = Rails.cache.fetch(cache_key, :expires_in => 5.minutes) do
			nearby_venues = Venue.in_bounds(proximity_box).where("color_rating > -1.0 OR is_live IS TRUE")
			nearby_venue_ids = nearby_venues.pluck(:id)
			faraway_venues = Venue.where("(color_rating > -1.0 OR is_live IS TRUE) AND id NOT IN (?)", nearby_venue_ids)
			Kaminari.paginate_array(nearby_venues.concat(faraway_venues))
			#Kaminari.paginate_array(nearby_venues.concat(faraway_venues)).page(params[:page]).per(num_page_entries)
		end
=end		


		if params[:page].to_i == 1
			cache_key = "lyt_map_by_parts/[#{lat.to_f.round(2)},#{long.to_f.round(2)}]_near"
			nearby_venues = Rails.cache.fetch(cache_key, :expires_in => 5.minutes) do
				Venue.in_bounds(proximity_box).where("color_rating > -1.0 OR is_live IS TRUE")
			end
			@venues = nearby_venues.page(params[:page]).per(num_page_entries)
		else
			cache_key = "lyt_map_by_parts/[#{lat.to_f.round(2)},#{long.to_f.round(2)}]_far"
			faraway_venues = Rails.cache.fetch(cache_key, :expires_in => 5.minutes) do
				Venue.where("(color_rating > -1.0 OR is_live IS TRUE) AND ((latitude < #{proximity_box.sw.lat} OR latitude > #{proximity_box.ne.lat}) AND (longitude < #{proximity_box.sw.lng} OR longitude > #{proximity_box.ne.lng}))")
			end
			@venues = faraway_venues.page(params[:page].to_i-1).per(num_page_entries)
		end

		@view_cache_key = cache_key+"/[#{lat.to_f.round(2)},#{long.to_f.round(2)}]/part_"+params[:page]
		#@venues = lit_venues.page(params[:page]).per(num_page_entries)
		render 'display_by_parts.json.jbuilder'
	end

	def search
		@user = User.find_by_authentication_token(params[:auth_token])

		if params[:instagram_location_id] == nil
			venue = Venue.fetch(params[:name], params[:formatted_address], params[:city], params[:state], params[:country], params[:postal_code], params[:phone_number], params[:latitude], params[:longitude])
			@venues = [venue]
		else
			@venues =[Venue.fetch_venues_for_instagram_pull(params[:name], params[:latitude], params[:longitude], params[:instagram_location_id], nil)]
		end

		render 'search.json.jbuilder'
	end

	def direct_fetch
		position_lat = params[:latitude]
		position_long = params[:longitude]

		ne_lat = params[:ne_latitude]
		ne_long = params[:ne_longitude]
		sw_lat = params[:sw_latitude]
		sw_long = params[:sw_longitude]

		query = params[:q]

		@venues = Venue.direct_fetch(query, position_lat, position_long, ne_lat, ne_long, sw_lat, sw_long).to_a

		render 'search.json.jbuilder'
	end

	def get_suggested_venues
		@user = User.find_by_authentication_token(params[:auth_token])
		@suggestions = Venue.near_locations(params[:latitude], params[:longitude])
		render 'get_suggested_venues.json.jbuilder'
	end

	def get_trending_venues 
		@venues = Rails.cache.fetch(:get_trending_venues, :expires_in => 5.minutes) do
			Venue.where("trend_position IS NOT NULL").order("trend_position ASC limit 10").includes(:venue_comments)
		end
	end

	def get_trending_venues_details
		@venues = Rails.cache.fetch(:get_trending_venues, :expires_in => 5.minutes) do
			Venue.where("trend_position IS NOT NULL").order("trend_position ASC limit 10").includes(:venue_comments)
		end		
	end

	def get_contexts
		#Hanlding both for individual venue and clusters.
		if params[:cluster_venue_ids] != nil
			@contexts = MetaData.cluster_top_meta_tags(params[:cluster_venue_ids])
			@key = "contexts/cluster/#{params[:cluster_venue_ids].first(10)}_#{params[:cluster_venue_ids].length}"
			render 'get_cluster_contexts.json.jbuilder'
		else
			@venue = Venue.find_by_id(params[:venue_id])
			@key = "contexts/venue/#{params[:venue_id]}"

			@contexts = Rails.cache.fetch(@key, :expires_in => 3.minutes) do
				MetaData.where("(NOW() - created_at) <= INTERVAL '1 DAY' AND venue_id = ?", params[:venue_id]).order("relevance_score DESC LIMIT 5")
			end

			MetaData.delay.bulck_relevance_score_update(@contexts)
			render 'get_contexts.json.jbuilder'
		end
	end

	def explore_venues
		previous_venue_ids = params[:previous_venue_ids]
		if previous_venue_ids == nil
			previous_venue_ids = []
		else
			previous_venue_ids = previous_venue_ids.split(',').map(&:to_i)
		end
		@venue = Venue.discover(params[:proximity], previous_venue_ids, params[:latitude], params[:longitude])
	end

	def get_quick_venue_overview
		@venue = Venue.find_by_id(params[:venue_id])
	end

	def get_quick_cluster_overview
		venue_ids = params[:cluster_venue_ids].split(',')
		cluster_lat = params[:cluster_latitude]
		cluster_long =  params[:cluster_longitude]
		zoom_level = params[:zoom_level]
		map_scale = params[:map_scale]

		@posts = VenueComment.where("venue_id IN (?)", venue_ids).order("id DESC LIMIT 4")
		@meta = MetaData.where("venue_id IN (?)", venue_ids).order("relevance_score DESC LIMIT 5")
	end

	def get_surrounding_feed_for_user
		lat = params[:latitude]
		long = params[:longitude]
		venue_ids = params[:venue_ids]

		fresh_pull = params[:fresh_pull]

		@user = User.find_by_authentication_token(params[:auth_token])

		if fresh_pull == "0"
			surrounding_posts = Rails.cache.fetch("surrounding_posts/#{@user.id}", :expires_in => 5.minutes) do
				Venue.surrounding_feed(lat, long, venue_ids)
			end
		else
			begin
				Rails.cache.delete("surrounding_posts/#{@user.id}")
			rescue
				puts "No cache present to delete"
			end
			surrounding_posts = Rails.cache.fetch("surrounding_posts/#{@user.id}", :expires_in => 5.minutes) do
				Venue.surrounding_feed(lat, long, venue_ids)
			end
		end
		
		@posts = Kaminari.paginate_array(surrounding_posts).page(params[:page]).per(10)
	end

	def check_vortex_proximity
		InstagramVortex.check_nearby_vortex_existence(params[:latitude], params[:longitude])
		render json: { success: true }
	end

	def get_questions
		if params[:venue_id] != nil
			@venue = Venue.find_by_id(params[:venue_id])
		else
			if params[:instagram_location_id]
				@venue = Venue.find_by_instagram_location_id(params[:instagram_location_id])
			else
				@venue = Venue.fetch(params[:name], params[:formatted_address], params[:city], params[:state], params[:country], params[:postal_code], params[:phone_number], params[:latitude], params[:longitude])
			end
		end
		@questions = @venue.venue_questions.where("created_at > ?", Time.now-1.day).includes(:user).order("ID DESC").page(params[:page]).per(15)
	end

	def get_question_comments
		venue_question = VenueQuestion.find_by_id(params[:venue_question_id])
		@question_comments = venue_question.venue_question_comments.order("ID DESC").page(params[:page]).per(15)
	end

	def post_new_question
		if params[:venue_id] != nil
			v_id = params[:venue_id]
		else
			if params[:instagram_location_id]
				@venue = Venue.find_by_instagram_location_id(params[:instagram_location_id])
			else
				@venue = Venue.fetch(params[:name], params[:formatted_address], params[:city], params[:state], params[:country], params[:postal_code], params[:phone_number], params[:latitude], params[:longitude])
			end
			v_id = @venue.id
		end
		vq = VenueQuestion.create!(:venue_id => v_id, :question => params[:question], :user_id => @user.id)
		if vq
			render json: { id: vq.id }
		else
			render json: { error: { code: ERROR_UNPROCESSABLE, messages: [message]} }, status: :unprocessable_entity
		end
	end

	def send_new_question_comment
		new_venue_question_comment = VenueQuestionComment.new_comment(params[:venue_question_id], params[:comment], params[:venue_id], params[:user_id], params[:user_on_location])
		if new_venue_question_comment
			VenueQuestion.find_by_id(params[:venue_question_id]).increment!(:num_comments, 1)
			render json: { success: true }
		else
			render json: { error: { code: ERROR_UNPROCESSABLE, messages: [message]} }, status: :unprocessable_entity
		end
	end

	def get_linked_user_lists
		@user = User.find_by_authentication_token(params[:auth_token])
		@feeds = Venue.linked_user_lists(params[:venue_id], @user.id)
	end


	private

	def venue
		@venue ||= Venue.find(params[:venue_id])
	end

	def venue_comment_params
		params.permit(:comment, :media_type, :media_url, :session)
	end
end
