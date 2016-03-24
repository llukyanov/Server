class Venue < ActiveRecord::Base
  include PgSearch  

  pg_search_scope :name_search, #name and/or associated meta data
    :against => [:ts_name_vector, :metaphone_name_vector],
    :using => {
      :tsearch => {
        :normalization => 2,
        :dictionary => 'simple',
        :any_word => true,
        :prefix => true,
        :tsvector_column => 'ts_name_vector',
      },
      :dmetaphone => {
        :tsvector_column => "metaphone_name_vector",
        #:prefix => true,
      },  
    },
    :ranked_by => "0.5*:trigram + :tsearch +:dmetaphone" #+ 0.3*Cast(venues.verified as integer)"#{}"(((:dmetaphone) + 1.5*(:trigram))*(:tsearch) + (:trigram))"    

  pg_search_scope :name_city_search, #name and/or associated meta data
    :against => :ts_name_city_vector,
    :using => {
      :tsearch => {
        :normalization => 2,
        :dictionary => 'simple',
        :any_word => true,
        :prefix => true,
        :tsvector_column => 'ts_name_city_vector',
      }  
    },
    :ranked_by => "0.5*:trigram + :tsearch +:dmetaphone"

  pg_search_scope :name_country_search, #name and/or associated meta data
    :against => :ts_name_country_vector,
    :using => {
      :tsearch => {
        :normalization => 2,
        :dictionary => 'simple',
        :any_word => true,
        :prefix => true,
        :tsvector_column => 'ts_name_country_vector',
      }  
    },
    :ranked_by => "0.5*:trigram + :tsearch +:dmetaphone"


  pg_search_scope :name_search_expd, #name and/or associated meta data
    :against => [:ts_name_vector_expd, :metaphone_name_vector_expd],
    :using => {
      :tsearch => {
        :normalization => 1,
        :dictionary => 'simple',
        :any_word => true,
        :prefix => true,
        :tsvector_column => 'ts_name_vector_expd',
      },
      :dmetaphone => {
        :tsvector_column => "metaphone_name_vector_expd",
        #:prefix => true,
      }  
    },
    :ranked_by => ":dmetaphone + :trigram*5 +:tsearch*4" 


  pg_search_scope :phonetic_search,
              :against => "metaphone_name_vector",
              :using => {
                :dmetaphone => {
                  :tsvector_column => "metaphone_name_vector",
                  :prefix => true
                }  
              },
              :ranked_by => ":dmetaphone"# + (0.25 * :trigram)"#":trigram"#

  pg_search_scope :meta_search, #name and/or associated meta data
    against: :meta_data_vector,
    using: {
      tsearch: {
        dictionary: 'english',
        #any_word: true,
        #prefix: true,
        tsvector_column: 'meta_data_vector'
      }
    }                

  pg_search_scope :fuzzy_name_search, lambda{ |target_name, rigor|
    raise ArgumentError unless rigor <= 1.0
    {
      :against => :name,
      :query => target_name,
      :using => {
        :trigram => {
          :threshold => rigor #higher value corresponds to stricter comparison
        }
      }
    }
  }
                
                          
#---------------------------------------------------------------------------------------->

  acts_as_mappable :default_units => :kms,
                     :default_formula => :sphere,
                     :distance_field_name => :distance,
                     :lat_column_name => :latitude,
                     :lng_column_name => :longitude

  validates :name, presence: true
  validates :latitude, presence: true
  validates :longitude, presence: true
  validate :validate_menu_link

  has_many :venue_ratings, :dependent => :destroy
  has_many :venue_comments, :dependent => :destroy
  has_many :tweets, :dependent => :destroy
  has_many :venue_messages, :dependent => :destroy
  has_many :menu_sections, :dependent => :destroy, :inverse_of => :venue
  has_many :menu_section_items, :through => :menu_sections
  has_many :lyt_spheres, :dependent => :destroy
  has_many :lytit_votes, :dependent => :destroy
  has_many :meta_datas, :dependent => :destroy
  has_many :instagram_location_id_lookups, :dependent => :destroy
  has_many :feed_venues
  has_many :feeds, through: :feed_venues
  has_many :activities, :dependent => :destroy
  has_many :activities, :dependent => :destroy
  has_many :events, :dependent => :destroy

  has_many :favorite_venues, :dependent => :destroy
  has_many :moment_requests, :dependent => :destroy

  belongs_to :user

  accepts_nested_attributes_for :venue_messages, allow_destroy: true, reject_if: proc { |attributes| attributes['message'].blank? or attributes['position'].blank? }

  MILE_RADIUS = 2

  scope :close_to, -> (latitude, longitude, distance_in_meters = 2000) {
    where(%{
      ST_DWithin(
        ST_GeographyFromText(
          'SRID=4326;POINT(' || venues.longitude || ' ' || venues.latitude || ')'
        ),
        ST_GeographyFromText('SRID=4326;POINT(%f %f)'),
        %d
      )
    } % [longitude, latitude, distance_in_meters])
  }

  scope :far_from, -> (latitude, longitude, distance_in_meters = 2000) {
    where(%{
      NOT ST_DWithin(
        ST_GeographyFromText(
          'SRID=4326;POINT(' || venues.longitude || ' ' || venues.latitude || ')'
        ),
        ST_GeographyFromText('SRID=4326;POINT(%f %f)'),
        %d
      )
    } % [longitude, latitude, distance_in_meters])
  }

  scope :inside_box, -> (sw_longitude, sw_latitude, ne_longitude, ne_latitude) {
    where(%{
        ST_GeographyFromText('SRID=4326;POINT(' || venues.longitude || ' ' || venues.latitude || ')') @ ST_MakeEnvelope(%f, %f, %f, %f, 4326) 
        } % [sw_longitude, sw_latitude, ne_longitude, ne_latitude])
  }
=begin
    where(%{
      ST_Intersects(
        ST_MakeEnvelope(%f, %f, %f, %f, 4326), ST_GeographyFromText('SRID=4326;POINT(' || venues.longitude || ' ' || venues.latitude || ')') 
        )} % [sw_longitude, sw_latitude, ne_longitude, ne_latitude])
  }


=begin    
    where(%{ST_GeographyFromText(
          'SRID=4326;POINT(' || venues.longitude || ' ' || venues.latitude || ')'
        ) 
      && ST_MakeEnvelope(%f, %f, %f, %f, 4326), 2223)
    } % [sw_longitude, sw_latitude, ne_longitude, ne_latitude])
  }
=end



  scope :visible, -> { joins(:lytit_votes).where('lytit_votes.created_at > ?', Time.now - LytitConstants.threshold_to_venue_be_shown_on_map.minutes) }


  #I. Search------------------------------------------------------->

  def Venue.lookup(query)
    Venue.search(query, nil, nil).first
  end

  def Venue.search(query, proximity_box, view_box)
    if proximity_box != nil      
      search_box = proximity_box
    elsif view_box != nil 
      sw_point = Geokit::LatLng.new(view_box[:sw_lat], view_box[:sw_long])
      ne_point =Geokit::LatLng.new(view_box[:ne_lat], view_box[:ne_lat])
      search_box = Geokit::Bounds.new(sw_point, ne_point)
    else
      search_box = Geokit::Bounds.from_point_and_radius([40.741140, -73.981917], 20, :units => :kms)
    end

    query_parts = query.split    
    #First search in proximity
    nearby_results = Venue.in_bounds(search_box).name_search(query).where("pg_search.rank >= ?", 0.0).with_pg_search_rank.limit(5).to_a
    if nearby_results.first == nil or nearby_results.first.pg_search_rank < 0.4
      geography = '%'+query_parts.last.downcase+'%'        
      #Nothing nearby, see if the user has specified a city at the end
      city_spec_results = Venue.name_city_search(query).where("pg_search.rank >= ? AND LOWER(city) LIKE ?", 0.0,
        geography).with_pg_search_rank.limit(5).to_a
      if city_spec_results.first == nil or city_spec_results.first.pg_search_rank < 0.4
        #Nothing super relevant came back from city, check by country
        country_spec_results = Venue.name_country_search(query).where("pg_search.rank >= ? AND LOWER(country) LIKE ?", 0.0,
          geography).with_pg_search_rank.limit(5).to_a
        if country_spec_results.first == nil or country_spec_results.first.pg_search_rank < 0.4
          p "Returning All Results"
          total_results = (nearby_results.concat(city_spec_results).concat(country_spec_results)).sort_by{|result| -result.pg_search_rank}.uniq
          #p total_results.each{|result| p"#{result.name} (#{result.pg_search_rank})"}
          return total_results
        else
          p "Returning Country Results"
          #p country_spec_results.each{|result| p"#{result.name} (#{result.pg_search_rank})"}
          return country_spec_results
        end
      else
        p "Returning City Results"
        #p city_spec_results.each{|result| p"#{result.name} (#{result.pg_search_rank})"}
        return city_spec_results
      end
    else
      p "Returning Nearby Results"
      #p nearby_results.each{|result| p"#{result.name} (#{result.pg_search_rank})"}
      return nearby_results
    end
  end



  def Venue.search_2(query, proximity_box, view_box)
    #Venue.search(query, nil, nil).each{|x| p"#{x.name} / #{x.pg_search_rank} / #{x.city} / #{x.country}"}
    if proximity_box != nil      
      search_box = proximity_box
    elsif view_box != nil 
      sw_point = Geokit::LatLng.new(view_box[:sw_lat], view_box[:sw_long])
      ne_point =Geokit::LatLng.new(view_box[:ne_lat], view_box[:ne_lat])
      search_box = Geokit::Bounds.new(sw_point, ne_point)
    else
      search_box = Geokit::Bounds.from_point_and_radius([40.741140, -73.981917], 20, :units => :kms)
    end
    
    query_parts = query.split
    nearby_results = Venue.in_bounds(search_box).name_search(query).where("pg_search.rank >= ? OR LOWER(name) LIKE ?", 0.44, '%'+query.downcase+'%').with_pg_search_rank.limit(10).to_a

    if nearby_results.count > 0
      puts "Returning Nearby ONLY!"
      nearby_results.each{|x| p"#{x.name} / #{x.pg_search_rank} / #{x.city} / #{x.country}"}
      return nearby_results
    elsif proximity_box == nil            
      direct_search = Venue.name_search(query).where("pg_search.rank >= ?", 0.44).with_pg_search_rank.limit(10).to_a
      if direct_search.count > 0    
        puts "Direct Lookup Result"
        direct_search.each{|x| p"#{x.name} / #{x.pg_search_rank} / #{x.city} / #{x.country}"}
        return direct_search
      else
        geography = '%'+query_parts.last.downcase+'%'        
        city_spec = Venue.name_city_search(query).where("pg_search.rank >= ? AND LOWER(city) LIKE ?", 0.44,
          geography).with_pg_search_rank.limit(10).to_a
        if city_spec.count > 0
          puts "City Lookup Result"
          city_spec.each{|x| p"#{x.name} / #{x.pg_search_rank} / #{x.city} / #{x.country}"}
          return city_spec
        else
          puts "Country Lookup Result"
          #country_spec
          country_spec = Venue.name_country_search(query).where("pg_search.rank >= ? AND LOWER(country) LIKE ?", 0.44,
            geography).with_pg_search_rank.limit(10).to_a
          country_spec.each{|x| p"#{x.name} / #{x.pg_search_rank} / #{x.city} / #{x.country}"}
          return country_spec
        end
      end
    else
      p "No results"
      return []
    end
  end

  def Venue.database_cleanup(num_days_back)
    #cleanup venue database by removing garbage/unused venues. This is necessary in order to manage
    #database size and improve searching/lookup performance. 
    #Keep venues that fit following criteria:
    #1. Venue is in a List
    #2. Venue has been Bookmarked
    #3. Venue is an Apple verified venue (address != nil, city != nil)
    #4. Venue CURRENTLY has a color rating
    #5. Venue has been posted at in the past 3 days
    num_venues_before_cleanup = Venue.all.count

    days_back = num_days_back || 3
    feed_venue_ids = "SELECT venue_id FROM feed_venues"
    criteria = "latest_posted_comment_time < ? AND venues.id NOT IN (#{feed_venue_ids}) AND (address is NULL OR city = ?) AND color_rating < 0"

    InstagramLocationIdLookup.all.joins(:venue).where(criteria, Time.now - days_back.days, "").delete_all
    p "Associated Inst Location Ids Cleared"    
    VenueComment.all.joins(:venue).where(criteria, Time.now - days_back.days, "").delete_all
    p "Associated Venue Comments Cleared"    
    MetaData.all.joins(:venue).where(criteria, Time.now - days_back.days, "").delete_all
    p "Associated Meta Data Cleared"
    Tweet.all.joins(:venue).where(criteria, Time.now - days_back.days, "").delete_all
    p "Associated Tweets Cleared"
    LytitVote.all.joins(:venue).where(criteria, Time.now - days_back.days, "").delete_all
    p "Associated Lytit Votes Cleared"
    LytSphere.all.joins(:venue).where(criteria, Time.now - days_back.days, "").delete_all
    p "Associated Lyt Spheres Cleared"
    VenuePageView.all.joins(:venue).where(criteria, Time.now - days_back.days, "").delete_all
    p "Associated Venue Page Views Cleared"

    Venue.where("latest_posted_comment_time < ? AND id NOT IN (#{feed_venue_ids}) AND (address is NULL OR city = ?) AND color_rating < 0", Time.now - days_back.days, '').delete_all
    p "Venues Cleared"
    num_venues_after_cleanup = Venue.all.count

    p"Venue Database cleanup complete! Venue Count Before: #{num_venues_before_cleanup}. Venue Count After: #{num_venues_after_cleanup}. Total Cleared: #{num_venues_before_cleanup - num_venues_after_cleanup}"
  end

  def details_hash
    {"address" => address, "city" => city, "state" => state, "country" => country, "postal_code" => postal_code, "latitude" => latitude, "longitude" => longitude}
  end      

  def self.direct_fetch(query, position_lat, position_long, ne_lat, ne_long, sw_lat, sw_long)
    if query != nil && query != ""
      if query.first =="/"  
        query[0] = ""
        meta_results = Venue.where("latitude > ? AND latitude < ? AND longitude > ? AND longitude < ?", sw_lat, ne_lat, sw_long, ne_long).meta_search(query).limit(20)
      else
        if (ne_lat.to_f != 0.0 && ne_long.to_f != 0.0) and (sw_lat.to_f != 0.0 && sw_long.to_f != 0.0)
          central_screen_point = [(ne_lat.to_f-sw_lat.to_f)/2.0 + sw_lat.to_f, (ne_long.to_f-sw_long.to_f)/2.0 + sw_long.to_f]
          if Geocoder::Calculations.distance_between(central_screen_point, [position_lat, position_long], :units => :km) <= 20 and Geocoder::Calculations.distance_between(central_screen_point, [ne_lat, ne_long], :units => :km) <= 100            
              search_box = Geokit::Bounds.from_point_and_radius(central_screen_point, 20, :units => :kms)
              Venue.search(query, search_box, nil)
          else
              outer_region = {:ne_lat => ne_lat, :ne_long => ne_long,:sw_lat => sw_lat ,:sw_long => sw_long}
              Venue.search(query, nil, outer_region)
          end
        else
          Venue.search(query, nil, nil)
        end
      end
    else
      []
    end
  end

  #Venue.search(query).limit(50).rotate(offset) if offset = Venue.search(query).limit(50).find_index{|b| b.name.size > 0 and b.name[0] == query.first}

  def self.fetch(vname, vaddress, vcity, vstate, vcountry, vpostal_code, vphone, vlatitude, vlongitude)
    lat_long_lookup = Venue.where("latitude = ? AND longitude = ?", vlatitude, vlongitude).fuzzy_name_search(vname, 0.8).first    
    
    if lat_long_lookup == nil
      center_point = [vlatitude, vlongitude]
      search_box = Geokit::Bounds.from_point_and_radius(center_point, 0.250, :units => :kms)
      result = Venue.search(vname, search_box, nil).first
      if result == nil
        if vaddress == nil
          if vcity != nil #city search
            search_box = Geokit::Bounds.from_point_and_radius(center_point, 10, :units => :kms)
            result = Venue.in_bounds(search_box).where("address IS NULL AND name = ? OR name = ?", vcity, vname).first
          end

          if vstate != nil && vcity == nil #state search
            search_box = Geokit::Bounds.from_point_and_radius(center_point, 100, :units => :kms)
            result = Venue.in_bounds(search_box).where("address IS NULL AND city IS NULL AND name = ? OR name = ?", vstate, vname).first
          end

          if (vcountry != nil && vstate == nil ) && vcity == nil #country search
            search_box = Geokit::Bounds.from_point_and_radius(center_point, 1000, :units => :kms)
            result = Venue.in_bounds(search_box).where("address IS NULL AND city IS NULL AND state IS NULL AND name = ? OR name = ?", vcountry, vname).first
          end
        else #venue search
          search_box = Geokit::Bounds.from_point_and_radius(center_point, 0.250, :units => :kms)
          result = Venue.search(vname, search_box, nil).first
          #result = Venue.in_bounds(search_box).fuzzy_name_search(vname, 0.8).first
        end
      end
    else
      result = lat_long_lookup
    end

    if result == nil
      if vlatitude != nil && vlongitude != nil 
        result = Venue.create_new_db_entry(vname, vaddress, vcity, vstate, vcountry, vpostal_code, vphone, vlatitude, vlongitude, nil, nil)
        result.update_columns(verified: true)
      else
        return nil
      end
    end

    if vaddress != nil && result.address == nil
      result.delay.calibrate_attributes(vname, vaddress, vcity, vstate, vcountry, vpostal_code, vphone, vlatitude, vlongitude)
    end

    return result 
  end

  def self.create_new_db_entry(name, address, city, state, country, postal_code, phone, latitude, longitude, instagram_location_id, origin_vortex)
    venue = Venue.create!(:name => name, :latitude => latitude, :longitude => longitude, :fetched_at => Time.now)
    
    if city == nil
      closest_venue = Venue.within(10, :units => :kms, :origin => [latitude, longitude]).where("city is not NULL").order("distance ASC").first
      if closest_venue != nil
        city = closest_venue.city
        country = closest_venue.country
      else
        if origin_vortex != nil
          city = origin_vortex.city
          country = origin_vortex.country
        else
          city = nil
          country = nil
        end  
      end
    end

    #city = city.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,'').to_s rescue nil#Removing accent marks

    venue.update_columns(address: address) 

    formatted_address = "#{address}, #{city}, #{state} #{postal_code}, #{country}"

    part1 = [address, city].compact.join(', ')
    part2 = [part1, state].compact.join(', ')
    part3 = [part2, postal_code].compact.join(' ')
    part4 = [part3, country].compact.join(', ')


    venue.update_columns(formatted_address: part4) 
    if city != nil
      venue.update_columns(city: city) 
    else
      venue.update_columns(city: '') 
    end
    venue.update_columns(state: state) 
    venue.update_columns(country: country)

    if postal_code != nil
      venue.postal_code = postal_code.to_s
    end
    
    if phone != nil
      venue.phone_number = Venue.formatTelephone(phone)
    end

    if venue.latitude < 0 && venue.longitude >= 0
      quadrant = "a"
    elsif venue.latitude < 0 && venue.longitude < 0
      quadrant = "b"
    elsif venue.latitude >= 0 && venue.longitude < 0
      quadrant = "c"
    else
      quadrant = "d"
    end
    venue.l_sphere = quadrant+(venue.latitude.round(1).abs).to_s+(venue.longitude.round(1).abs).to_s
    venue.save

    if address != nil && name != nil
      if address.gsub(" ","").gsub(",", "") == name.gsub(" ","").gsub(",", "")
        venue.is_address = true
      end
    end

    if instagram_location_id != nil
      venue.update_columns(instagram_location_id: instagram_location_id)  
    end

    venue.save

    if origin_vortex != nil
      venue.update_columns(instagram_vortex_id: origin_vortex.id)     
    end    
    venue.delay.set_time_zone_and_offset(origin_vortex)

    if address != nil
      venue.update_columns(verified: true)
    end

    return venue    
  end

  def set_time_zone_and_offset(origin_vortex)
    if origin_vortex == nil
      Timezone::Configure.begin do |c|
      c.username = 'LYTiT'
      end
      timezone = Timezone::Zone.new :latlon => [self.latitude, self.longitude] rescue nil

      self.time_zone = timezone.active_support_time_zone rescue nil
      self.time_zone_offset = Time.now.in_time_zone(timezone.active_support_time_zone).utc_offset/3600.0 rescue nil
      self.save
    else
      self.update_columns(time_zone: origin_vortex.time_zone)
      self.update_columns(time_zone_offset: origin_vortex.time_zone_offset)
      #Set nearest instagram vortex id if a vortex within 10kms present
      radius  = 10000
      nearest_vortex = InstagramVortex.within(radius.to_i, :units => :kms, :origin => [self.latitude, self.longitude]).order('distance ASC').first
      self.update_columns(instagram_vortex_id: nearest_vortex.id)
    end
  end

  def Venue.fill_in_time_zone_offsets
    radius  = 10000
    for venue in Venue.all.where("time_zone_offset IS NULL")
      closest_vortex = InstagramVortex.within(radius.to_i, :units => :kms, :origin => [venue.latitude, venue.longitude]).where("time_zone_offset IS NOT NULL").order('distance ASC').first
      venue.update_columns(time_zone_offset: closest_vortex.time_zone_offset)
    end
  end

  def Venue.calibrate_venues_after_daylight_savings
    for vortex in InstagramVortex.all
      p "Vortex: #{vortex.city}"
      vortex.set_timezone_offsets
      radius = 10
      vortex_venues = Venue.within(radius.to_i, :units => :kms, :origin => [vortex.latitude, vortex.longitude])
      vortex_venues.update_all(instagram_vortex_id: vortex.id)
      vortex_venues.update_all(time_zone: vortex.time_zone)
      vortex_venues.update_all(time_zone_offset: vortex.time_zone_offset)
    end
  end

  def calibrate_attributes(auth_name, auth_address, auth_city, auth_state, auth_country, auth_postal_code, auth_phone, auth_latitude, auth_longitude)
    #We calibrate with regards to the Apple Maps database
    auth_city = auth_city.mb_chars.normalize(:kd).gsub(/[^\x00-\x7F]/n,'').to_s rescue nil#Removing accent marks
    #Name
    if self.name != auth_name
      self.name = auth_name
    end

    #Address
    if (self.city == nil || self.state == nil || self.city = "" || self.city = ' ') or (self.city != auth_city) #Add venue details if they are not present
      self.update_columns(formatted_address: Venue.address_formatter(address, city, state, postal_code, country))
      self.update_columns(city: auth_city)
      self.update_columns(state: auth_state)
      self.update_columns(country: auth_country) 

      if auth_phone != nil
        self.phone_number = Venue.formatTelephone(auth_phone)
      end
      self.save
    end

    if self.address == nil && (auth_address != nil && auth_address != "")
      self.update_columns(address: auth_address)
    end

    #Geo
    if auth_latitude != nil and self.latitude != auth_latitude
      self.latitude = auth_latitude
    end

    if auth_longitude != nil and self.longitude != auth_longitude
      self.longitude = auth_longitude
    end      

    #LSphere
    if self.l_sphere == nil
      if self.latitude < 0 && self.longitude >= 0
        quadrant = "a"
      elsif self.latitude < 0 && self.longitude < 0
        quadrant = "b"
      elsif self.latitude >= 0 && self.longitude < 0
        quadrant = "c"
      else
        quadrant = "d"
      end
      self.l_sphere = quadrant+(self.latitude.round(1).abs).to_s+(self.longitude.round(1).abs).to_s
      self.save
    end

    #Timezones
    if self.time_zone == nil #Add timezone of venue if not present
      Timezone::Configure.begin do |c|
        c.username = 'LYTiT'
      end
      timezone = Timezone::Zone.new :latlon => [latitude, longitude] rescue nil
      self.time_zone = timezone.active_support_time_zone rescue nil
    end

    if self.time_zone_offset == nil
      self.time_zone_offset = Time.now.in_time_zone(self.time_zone).utc_offset/3600.0  rescue nil
    end
    
    self.save
  end

  def self.address_formatter(address, city, state, postal_code, country)
    address = address || "X"
    city = city || "X"
    state = state || "X"
    postal_code = postal_code || "X"
    country = country || "X"

    concat = "#{address}, #{city}, #{state} #{postal_code}, #{country}"
    response = ""
    while response != nil
      response = concat.slice! "X, "
      response = concat.slice! " X"      
    end
    concat.slice! "X, "
    concat.slice! "X,"
    return concat
  end

  #Uniform formatting of venues phone numbers into a "(XXX)-XXX-XXXX" style
  def Venue.formatTelephone(number)
    if number == nil
      return
    end

    digits = number.gsub(/\D/, '').split(//)
    lead = digits[0]

    if (digits.length == 11)
      digits.shift
    end

    digits = digits.join
    if (digits.length == 10)
      number = '(%s)-%s-%s' % [digits[0,3], digits[3,3], digits[6,4]]
    end
  end

  #Temp method to reformat older telephones
  def reformatTelephone
    number = phone_number
    if number == nil
      return
    end

    digits = number.gsub(/\D/, '').split(//)
    lead = digits[0]

    if (digits.length == 11)
      digits.shift
    end

    digits = digits.join
    if (digits.length == 10)
      number = '(%s)-%s-%s' % [digits[0,3], digits[3,3], digits[6,4]]
    end
    update_columns(phone_number: number)
  end

  def set_hours
    venue_foursquare_id = self.foursquare_id

    if venue_foursquare_id == nil      
      foursquare_venue = Venue.foursquare_venue_lookup(name, self.latitude, self.longitude, self.city)
      if foursquare_venue != nil && foursquare_venue != "F2 ERROR"        
        venue_foursquare_id = foursquare_venue.id
        self.update_columns(foursquare_id: venue_foursquare_id)
      else
        if foursquare_venue == "F2 ERROR"
          puts "Encountered Error"
          return {}
        else
          self.update_columns(open_hours: {"NA"=>"NA"})
          return open_hours
        end
      end
    end

    if venue_foursquare_id != nil
      client = Foursquare2::Client.new(:client_id => '35G1RAZOOSCK2MNDOMFQ0QALTP1URVG5ZQ30IXS2ZACFNWN1', :client_secret => 'ZVMBHYP04JOT2KM0A1T2HWLFDIEO1FM3M0UGTT532MHOWPD0', :api_version => '20120610')
      foursquare_venue_with_details = client.venue(venue_foursquare_id) rescue "F2 ERROR"
      if foursquare_venue_with_details == "F2 ERROR"
        puts "Encountered Error"
        return {}
      end
      if foursquare_venue_with_details != nil
        fq_open_hours = foursquare_venue_with_details.hours #|| foursquare_venue_with_details.popular
        fq_popular_hours = foursquare_venue_with_details.popular

        self.set_open_hours(fq_open_hours)
        self.set_popular_hours(fq_popular_hours)
      else
        self.update_columns(open_hours: {"NA"=>"NA"})
        self.update_columns(popular_hours: {"NA"=>"NA"})
      end
    else
      self.update_columns(open_hours: {"NA"=>"NA"})
      self.update_columns(popular_hours: {"NA"=>"NA"})
    end
    return open_hours
  end

  def set_open_hours(fq_open_hours)
    if fq_open_hours != nil
      open_hours_hash = Hash.new
      timeframes = fq_open_hours.timeframes
      utc_offset_hours = self.time_zone_offset || 0.0

      for timeframe in timeframes
        if timeframe.open.first.renderedTime != "None"
          days = Venue.create_days_array(timeframe.days, utc_offset_hours)
          for day in days
            open_spans = timeframe.open
            span_hash = Hash.new
            i = 0
            for span in open_spans            
              frame_hash = Hash.new
              open_close_array = Venue.convert_span_to_minutes(span.renderedTime)                      
              frame_hash["frame_"+i.to_s] = {"open_time" => open_close_array.first, "close_time" => open_close_array.last}            
              span_hash.merge!(frame_hash)
              i += 1
            end
            open_hours_hash[day] = span_hash
          end
        end
      end
      self.update_columns(open_hours: open_hours_hash)
    else
      self.update_columns(open_hours: {"NA"=>"NA"})
    end          
  end

  def set_popular_hours(fq_popular_hours)
    if fq_popular_hours != nil
      popular_hours_hash = Hash.new
      timeframes = fq_popular_hours.timeframes
      utc_offset_hours = self.time_zone_offset || 0.0

      for timeframe in timeframes
        if timeframe.open.first.renderedTime != "None"    
          days = Venue.create_days_array(timeframe.days, utc_offset_hours)
          for day in days
            popular_spans = timeframe.open
            span_hash = Hash.new
            i = 0
            for span in popular_spans            
              frame_hash = Hash.new
              open_close_array = Venue.convert_span_to_minutes(span.renderedTime)                      
              frame_hash["frame_"+i.to_s] = {"start_time" => open_close_array.first, "end_time" => open_close_array.last}            
              span_hash.merge!(frame_hash)
              i += 1
            end
            popular_hours_hash[day] = span_hash
          end
        end
      end
      self.update_columns(popular_hours: popular_hours_hash)
    else
      self.update_columns(popular_hours: {"NA"=>"NA"})
    end    
  end

  def Venue.create_days_array(timeframe_days, venue_utc_offset)
    days = Hash.new
    days["Mon"] = 1
    days["Tue"] = 2
    days["Wed"] = 3
    days["Thu"] = 4
    days["Fri"] = 5
    days["Sat"] = 6
    days["Sun"] = 7

    days_array = []

    split_timeframe_days = timeframe_days.split(",")

    for timeframe in split_timeframe_days
      timeframe.strip!
      if timeframe.include?("–")
        #Indicates a range of dates 'Mon-Sun'
        timeframe_array = timeframe.split("–")
        commence_day = timeframe_array.first
        end_day = timeframe_array.last
        if days[commence_day] != nil && days[end_day] != nil
          [*days[commence_day]..days[end_day]].each{|day_num| days_array << days.key(day_num)}
        end
      else
        #Single day timeframe, i.e 'Mon'
        if timeframe == "Today"
          timeframe =  Date::ABBR_DAYNAMES[(Time.now.utc+venue_utc_offset.hours).wday]
        end
        days_array << timeframe
      end
    end
    return days_array
  end

  def Venue.convert_span_to_minutes(span)
    span_array=span.split("–")
    opening = span_array.first
    closing = span_array.last

    if opening == "24 Hours"
      opening_time = 0.0
      closing_time = 0.0
    else
      if opening.last(2) == "AM"
        opening_time = opening.split(" ").first.gsub(":",".").to_f
      elsif opening == "Midnight"
        opening_time = 0.0
      elsif opening == "Noon"
        opening_time = 12.0      
      else
        opening_time = opening.split(" ").first.gsub(":",".").to_f+12.0
      end

      if closing.last(2) == "PM"
        closing_time = closing.split(" ").first.gsub(":",".").to_f+12.0
      elsif closing == "Midnight"
        closing_time = 0.0
      elsif closing == "Noon"
        closing_time = 12.0
      else
        if opening.last(2) == "PM"
          closing_time = closing.split(" ").first.gsub(":",".").to_f+24.0
        else
          closing_time = closing.split(" ").first.gsub(":",".").to_f
        end
      end
    end

    return [opening_time, closing_time]
  end

  def in_timespan?(hour_type, date_time)
    if hour_type == "open_hours"
      hour_type = self.open_hours
      t_0 = "open_time"
      t_n = "close_time"
    else
      hour_type = self.popular_hours
      t_0 = "start_time"
      t_n = "end_time"
    end

    in_timespan = nil
    if hour_type == {} || hour_type == {"NA"=>"NA"}
      in_timespan = true   
    else
      utc_offset = self.time_zone_offset || 0.0
      local_time = date_time.utc.hour.to_f+date_time.utc.min.to_f/100.0+utc_offset
      if local_time < 0 
        #utc is ahead of local time
        local_time += 24
      end
      today = Date::ABBR_DAYNAMES[(date_time.utc+utc_offset.hours).wday]
      today_time_spans = hour_type[today]
      yesterday = Date::ABBR_DAYNAMES[(date_time.utc+utc_offset.hours).wday-1]
      yesterday_time_spans = hour_type[yesterday]

      if today_time_spans == nil
        if yesterday_time_spans != nil
          if yesterday_time_spans.values.last[t_n] > 24.0 && (yesterday_time_spans.values.last[t_n] - 24.0) >= local_time
            today_time_spans = yesterday_time_spans
            frames = yesterday_time_spans.values
          else
            in_timespan = false
          end
        else
          in_timespan = false
        end
      else
        frames = today_time_spans.values
        if frames.last[t_n].to_i == 0.0
          close_time = 24.0
        else
          close_time = frames.last[t_n]
        end

        #if the post is coming in at 2:00 in the morning we have to look at the previous days business hours (applicable to nightlife establishments)
        if (close_time > 24.0 && (close_time - 24.0) >= local_time)
          yesterday = Date::ABBR_DAYNAMES[(date_time.utc+utc_offset.hours).wday-1]
          if hour_type[yesterday] != nil
            frames = hour_type[yesterday].values
          else
            in_timespan = false
          end
        end
      end

      if in_timespan == nil
        for frame in frames
          open_time = frame[t_0]
 
          if frame[t_n].to_i == 0.0
            close_time = 24.0
          else
            close_time = frame[t_n]
          end

          if (close_time > 24.0 && (close_time - 24.0) >= local_time)
            time_range = (((date_time.utc+utc_offset.hours) - (date_time.utc+utc_offset).hour.hour - (date_time.utc+utc_offset).min.minutes) - (24.0-open_time).hours).to_i..(((date_time.utc+utc_offset) - (date_time.utc+utc_offset).hour.hour - (date_time.utc+utc_offset).min.minutes) + close_time.hours).to_i
          else
            time_range = (((date_time.utc+utc_offset.hours).utc - (date_time.utc+utc_offset.hours).utc.hour.hour - (date_time.utc+utc_offset.hours).utc.min.minutes) + open_time.hours).to_i..(((date_time.utc+utc_offset.hours).utc - (date_time.utc+utc_offset.hours).utc.hour.hour - (date_time.utc+utc_offset.hours).utc.min.minutes) + close_time.hours).to_i
          end

          in_timespan = (time_range === (date_time.utc+utc_offset.hours).to_i)
          if in_timespan == true
            break
          end
        end
      end
    end
    return in_timespan
  end  

  def is_open?
    in_timespan?("open_hours", Time.now)
  end
  
  def is_popular?
    if open_hours == {}
      self.set_hours
    end
    in_timespan?("popular_hours", Time.now)
  end

  #------------------------------------------------------------------------>


  #II. Venue Popularity Ranking Functionality --------------------------------->
  def view(user_id)
    view = VenuePageView.new(:user_id => user_id, :venue_id => self.id, :venue_lyt_sphere =>  self.l_sphere)
    view.save
  end

  def account_page_view(u_id)
    view_half_life = 120.0 #minutes
    latest_page_view_time_wrapper = latest_page_view_time || Time.now
    new_page_view_count = (self.page_views * 2 ** ((-(Time.now - latest_page_view_time_wrapper)/60.0) / (view_half_life))).round(4)+1.0

    self.update_columns(page_views: new_page_view_count)
    self.update_columns(latest_page_view_time: Time.now)
    FeedUser.joins(feed: :feed_venues).where("venue_id = ?", self.id).each{|feed_user| feed_user.update_interest_score(0.05)}
  end

=begin
  def update_linked_list_interest_scores
    linked_list_ids = "SELECT feed_id FROM feed_venues WHERE venue_id = #{self.id}"
    feed_users = FeedUser.where("feed_id IN (?)", linked_list_ids).update_all(interest_score: ) #update using 
  end
=end  

  def ranking_change(new_ranking)
    current_ranking = self.trend_position
    if current_ranking == nil
      return 1
    else
      if new_ranking.to_i == current_ranking.to_i
        return 0
      elsif new_ranking.to_i < current_ranking.to_i
        return 1
      else
        return -1
      end
    end
  end

  def Venue.discover(proximity, previous_venue_ids, user_lat, user_long)
    num_diverse_venues = 50
    nearby_radius = 5000.0 * 1/1000 #* 0.000621371 #meters to miles
    center_point = [user_lat, user_long]
    proximity_box = Geokit::Bounds.from_point_and_radius(center_point, nearby_radius, :units => :kms)

    previous_venue_ids = previous_venue_ids || "0"

    if proximity == "nearby"
      venue = Venue.in_bounds(proximity_box).where("id NOT IN (#{previous_venue_ids}) AND rating IS NOT NULL").order("popularity_rank DESC").limit(num_diverse_venues).shuffle.first
      if venue == nil
          if previous_venue_ids == "0"
            venue = Venue.where("(latitude <= #{proximity_box.sw.lat} OR latitude >= #{proximity_box.ne.lat}) OR (longitude <= #{proximity_box.sw.lng} OR longitude >= #{proximity_box.ne.lng}) AND rating IS NOT NULL").order("popularity_rank DESC").limit(num_diverse_venues).shuffle.first
          else
            venue = []
          end
      end
    else
      venue = Venue.where("(latitude <= #{proximity_box.sw.lat} OR latitude >= #{proximity_box.ne.lat}) OR (longitude <= #{proximity_box.sw.lng} OR longitude >= #{proximity_box.ne.lng}) AND rating IS NOT NULL").order("popularity_rank DESC").limit(num_diverse_venues).shuffle.first
    end

    return venue
  end

  def Venue.trending_venues(user_lat, user_long)
    total_trends = 10
    nearby_ratio = 0.7
    nearby_count = total_trends*nearby_ratio
    global_count = (total_trends-nearby_count)
    center_point = [user_lat, user_long]
    #proximity_box = Geokit::Bounds.from_point_and_radius(center_point, 5, :units => :kms)


    nearby_trends = Venue.close_to(center_point.first, center_point.last, 5000).where("rating IS NOT NULL").order("popularity_rank DESC").limit(nearby_count)
    if nearby_trends.count == 0
      global_trends = Venue.far_from(center_point.first, center_point.last, 50*1000).where("rating IS NOT NULL").order("popularity_rank DESC").limit(total_trends)
      return global_trends.shuffle
    else
      global_trends = Venue.far_from(center_point.first, center_point.last, 50*1000).where("rating IS NOT NULL").order("popularity_rank DESC").limit(global_count)
      return (nearby_trends+global_trends).shuffle
    end
     
  end
  #----------------------------------------------------------------------->


  #III. Instagram Related Functionality --------------------------------------->
  def self.populate_lookup_ids
    v = Venue.where("instagram_location_id IS NOT NULL")
    for v_hat in v 
      if not InstagramLocationIdLookup.where("venue_id = ?", v_hat.id).any?
        InstagramLocationIdLookup.create!(:venue_id => v_hat.id, :instagram_location_id => v_hat.instagram_location_id)
      end
    end
  end

  #name checker for instagram venue creation
  def Venue.name_is_proper?(vname) 
    emoji_and_symbols = ["💗", "❤", "✌", "😊", "😀", "😁", "😂", "😃", "😄", "😅", "😆", "😇", "😈", "👿", "😉", "😊", "☺️", "😋", "😌", "😍", "😎", "😏", "😐", "😑", "😒", "😓", "😔", "😕", "😖", "😗", "😘", "😙", "😚", "😛", "😜", "😝", "😞", "😟", "😠", 
      "😡", "😢", "😣", "😤", "😥", "😦", "😧", "😨", "😩", "😪", "😫", "😬", "😭", "😮", "😯", "😰", "😱", "😲", "😳", "😴", "😵", "😶", "😷", "🙁", "🙂", "😸", "😹", "😺", "😻", "😼", "😽", "😾", "😿", "🙀", "👣", "👤", "👥", "👦", "👧", "👨", "👩", "👨‍",
      "👶", "👷", "👸", "💂", "👼", "🎅", "👻", "👹", "👺", "💩", "💀", "👽", "👾", "🙇", "💁", "🙅", "🙆", "🙋", "🙎", "🙍", "💆", "💇", "💑", "👩‍❤️‍👩", "👨‍❤️‍👨", "💏", "👩‍❤️‍💋‍👩", "👨‍❤️‍💋‍👨", "💅", "👂", "👀", "👃", "👄", "💋", "👅👋", "👍", "👎", "☝️", "👆", "👇", 
      "👈", "👉", "👌", "✌️", "👊", "✊", "✋", "💪", "👐", "🙌", "👏", "🙏", "🖐", "🖕", "🖖", "👦\u{1F3FB}", "👧\u{1F3FB}", "👨\u{1F3FB}", "👩\u{1F3FB}", "👮\u{1F3FB}", "👰\u{1F3FB}", "👱\u{1F3FB}", "👲\u{1F3FB}", "👳\u{1F3FB}", "👴\u{1F3FB}", "👵\u{1F3FB}", "👶\u{1F3FB}", 
      "👷\u{1F3FB}", "👸\u{1F3FB}", "💂\u{1F3FB}", "👼\u{1F3FB}", "🎅\u{1F3FB}", "🙇\u{1F3FB}", "💁\u{1F3FB}", "🙅\u{1F3FB}", "🙆\u{1F3FB}", "🙋\u{1F3FB}", "🙎\u{1F3FB}", "🙍\u{1F3FB}", "💆\u{1F3FB}", "💇\u{1F3FB}", "💅\u{1F3FB}", "👂\u{1F3FB}", "👃\u{1F3FB}", "👋\u{1F3FB}", 
      "👍\u{1F3FB}", "👎\u{1F3FB}", "☝\u{1F3FB}", "👆\u{1F3FB}", "👇\u{1F3FB}", "👈\u{1F3FB}", "👉\u{1F3FB}", "👌\u{1F3FB}", "✌\u{1F3FB}", "👊\u{1F3FB}", "✊\u{1F3FB}", "✋\u{1F3FB}", "💪\u{1F3FB}", "👐\u{1F3FB}", "🙌\u{1F3FB}", "👏\u{1F3FB}", "🙏\u{1F3FB}", "🖐\u{1F3FB}", 
      "🖕\u{1F3FB}", "🖖\u{1F3FB}", "👦\u{1F3FC}", "👧\u{1F3FC}", "👨\u{1F3FC}", "👩\u{1F3FC}", "👮\u{1F3FC}", "👰\u{1F3FC}", "👱\u{1F3FC}", "👲\u{1F3FC}", "👳\u{1F3FC}", "👴\u{1F3FC}", "👵\u{1F3FC}", "👶\u{1F3FC}", "👷\u{1F3FC}", "👸\u{1F3FC}", "💂\u{1F3FC}", "👼\u{1F3FC}", 
      "🎅\u{1F3FC}", "🙇\u{1F3FC}", "💁\u{1F3FC}", "🙅\u{1F3FC}", "🙆\u{1F3FC}", "🙋\u{1F3FC}", "🙎\u{1F3FC}", "🙍\u{1F3FC}", "💆\u{1F3FC}", "💇\u{1F3FC}", "💅\u{1F3FC}", "👂\u{1F3FC}", "👃\u{1F3FC}", "👋\u{1F3FC}", "👍\u{1F3FC}", "👎\u{1F3FC}", "☝\u{1F3FC}", "👆\u{1F3FC}", 
      "👇\u{1F3FC}", "👈\u{1F3FC}", "👉\u{1F3FC}", "👌\u{1F3FC}", "✌\u{1F3FC}", "👊\u{1F3FC}", "✊\u{1F3FC}", "✋\u{1F3FC}", "💪\u{1F3FC}", "👐\u{1F3FC}", "🙌\u{1F3FC}", "👏\u{1F3FC}", "🙏\u{1F3FC}", "🖐\u{1F3FC}", "🖕\u{1F3FC}", "🖖\u{1F3FC}", "👦\u{1F3FD}", "👧\u{1F3FD}", 
      "👨\u{1F3FD}", "👩\u{1F3FD}", "👮\u{1F3FD}", "👰\u{1F3FD}", "👱\u{1F3FD}", "👲\u{1F3FD}", "👳\u{1F3FD}", "👴\u{1F3FD}", "👵\u{1F3FD}", "👶\u{1F3FD}", "👷\u{1F3FD}", "👸\u{1F3FD}", "💂\u{1F3FD}", "👼\u{1F3FD}", "🎅\u{1F3FD}", "🙇\u{1F3FD}", "💁\u{1F3FD}", "🙅\u{1F3FD}", 
      "🙆\u{1F3FD}", "🙋\u{1F3FD}", "🙎\u{1F3FD}", "🙍\u{1F3FD}", "💆\u{1F3FD}", "💇\u{1F3FD}", "💅\u{1F3FD}", "👂\u{1F3FD}", "👃\u{1F3FD}", "👋\u{1F3FD}", "👍\u{1F3FD}", "👎\u{1F3FD}", "☝\u{1F3FD}", "👆\u{1F3FD}", "👇\u{1F3FD}", "👈\u{1F3FD}", "👉\u{1F3FD}", "👌\u{1F3FD}", 
      "✌\u{1F3FD}", "👊\u{1F3FD}", "✊\u{1F3FD}", "✋\u{1F3FD}", "💪\u{1F3FD}", "👐\u{1F3FD}", "🙌\u{1F3FD}", "👏\u{1F3FD}", "🙏\u{1F3FD}", "🖐\u{1F3FD}", "🖕\u{1F3FD}", "🖖\u{1F3FD}", "👦\u{1F3FE}", "👧\u{1F3FE}", "👨\u{1F3FE}", "👩\u{1F3FE}", "👮\u{1F3FE}", "👰\u{1F3FE}", 
      "👱\u{1F3FE}", "👲\u{1F3FE}", "👳\u{1F3FE}", "👴\u{1F3FE}", "👵","\u{1F3FE}", "👶","\u{1F3FE}", "👷","\u{1F3FE}", "👸","\u{1F3FE}", "💂","\u{1F3FE}", "👼","\u{1F3FE}", "🎅","\u{1F3FE}", "🙇","\u{1F3FE}", "💁","\u{1F3FE}", "🙅","\u{1F3FE}", "🙆","\u{1F3FE}", "🙋","\u{1F3FE}", 
      "🙎","\u{1F3FE}", "🙍","\u{1F3FE}", "💆","\u{1F3FE}", "💇","\u{1F3FE}", "💅","\u{1F3FE}", "👂","\u{1F3FE}", "👃","\u{1F3FE}", "👋","\u{1F3FE}", "👍","\u{1F3FE}", "👎","\u{1F3FE}", "☝","\u{1F3FE}", "👆","\u{1F3FE}", "👇","\u{1F3FE}", "👈","\u{1F3FE}", "👉","\u{1F3FE}", "👌",
      "\u{1F3FE}", "✌\u{1F3FE}", "👊","\u{1F3FE}", "✊","\u{1F3FE}", "✋","\u{1F3FE}", "💪","\u{1F3FE}", "👐\u{1F3FE}", "🙌\u{1F3FE}", "👏\u{1F3FE}", "🙏\u{1F3FE}", "🖐\u{1F3FE}", "🖕\u{1F3FE}", "🖖\u{1F3FE}", "👦\u{1F3FE}", "👧\u{1F3FE}", "👨\u{1F3FE}", "👩\u{1F3FE}", "👮\u{1F3FE}", 
      "👰\u{1F3FE}", "👱\u{1F3FE}", "👲\u{1F3FE}", "👳\u{1F3FE}", "👴\u{1F3FE}", "👵\u{1F3FE}", "👶\u{1F3FE}", "👷\u{1F3FE}", "👸\u{1F3FE}", "💂\u{1F3FE}", "👼\u{1F3FE}", "🎅\u{1F3FE}", "🙇\u{1F3FE}", "💁\u{1F3FE}", "🙅\u{1F3FE}", "🙆\u{1F3FE}", "🙋\u{1F3FE}", "🙎\u{1F3FE}", "🙍\u{1F3FE}", 
      "💆\u{1F3FE}", "💇\u{1F3FE}", "💅\u{1F3FE}", "👂\u{1F3FE}", "👃\u{1F3FE}", "👋\u{1F3FE}", "👍\u{1F3FE}", "👎\u{1F3FE}", "☝\u{1F3FE}", "👆\u{1F3FE}", "👇\u{1F3FE}", "👈\u{1F3FE}", "👉\u{1F3FE}", "👌\u{1F3FE}", "✌\u{1F3FE}", "👊\u{1F3FE}", "✊\u{1F3FE}", "✋\u{1F3FE}", "💪\u{1F3FE}", 
      "👐\u{1F3FE}", "🙌\u{1F3FE}", "👏\u{1F3FE}", "🙏\u{1F3FE}", "🖐\u{1F3FE}", "🖕\u{1F3FE}", "🖖\u{1F3FE}", "🌱", "🌲", "🌳", "🌴", "🌵", "🌷", "🌸", "🌹", "🌺", "🌻", "🌼", "💐", "🌾", "🌿", "🍀", "🍁", "🍂", "🍃", "🍄", "🌰", "🐀", "🐁", "🐭", "🐹", "🐂", "🐃", "🐄", "🐮", "🐅", 
      "🐆", "🐯", "🐇", "🐰", "🐈", "🐱", "🐎", "🐴", "🐏", "🐑", "🐐", "🐓", "🐔", "🐤", "🐣", "🐥", "🐦", "🐧", "🐘", "🐪", "🐫", "🐗", "🐖", "🐷", "🐽", "🐕", "🐩", "🐶", "🐺", "🐻", "🐨", "🐼", "🐵", "🙈", "🙉", "🙊", "🐒", "🐉", "🐲", "🐊", "🐍", "🐢", "🐸", "🐋", "🐳", "🐬", 
      "🐙", "🐟", "🐠", "🐡", "🐚", "🐌", "🐛", "🐜", "🐝", "🐞", "🐾", "⚡️", "🔥", "🌙", "☀️", "⛅️", "☁️", "💧", "💦", "☔️", "💨", "❄️", "🌟", "⭐️", "🌠", "🌄", "🌅", "🌈", "🌊", "🌋", "🌌", "🗻", "🗾", "🌐", "🌍", "🌎", "🌏", "🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘", "🌚", "🌝", 
      "🌛", "🌜", "🌞", "🍅", "🍆", "🌽", "🍠", "🍇", "🍈", "🍉", "🍊", "🍋", "🍌", "🍍", "🍎", "🍏", "🍐", "🍑", "🍒", "🍓", "🍔", "🍕", "🍖", "🍗", "🍘", "🍙", "🍚", "🍛", "🍜", "🍝", "🍞", "🍟", "🍡", "🍢", "🍣", "🍤", "🍥", "🍦", "🍧", "🍨", "🍩", "🍪", "🍫", "🍬", "🍭", "🍮", 
      "🍯", "🍰", "🍱", "🍲", "🍳", "🍴", "🍵", "☕️", "🍶", "🍷", "🍸", "🍹", "🍺", "🍻", "🍼🎀", "🎁", "🎂", "🎃", "🎄", "🎋", "🎍", "🎑", "🎆", "🎇", "🎉", "🎊", "🎈", "💫", "✨", "💥", "🎓", "👑", "🎎", "🎏", "🎐", "🎌", "🏮", "💍", "❤️", "💔", "💌", "💕", "💞", "💓", "💗", "💖", 
      "💘", "💝", "💟", "💜", "💛", "💚", "💙", "🏃", "🚶", "💃", "🚣", "🏊", "🏄", "🛀", "🏂", "🎿", "⛄️", "🚴", "🚵", "🏇", "⛺️", "🎣", "⚽️", "🏀", "🏈", "⚾️", "🎾", "🏉", "⛳️", "🏆", "🎽", "🏁", "🎹", "🎸", "🎻", "🎷", "🎺", "🎵", "🎶", "🎼", "🎧", "🎤", "🎭", "🎫", "🎩", "🎪", 
      "🎬", "🎨", "🎯", "🎱", "🎳", "🎰", "🎲", "🎮", "🎴", "🃏", "🀄️", "🎠", "🎡", "🎢", "🚃", "🚞", "🚂", "🚋", "🚝", "🚄", "🚅", "🚆", "🚇", "🚈", "🚉", "🚊", "🚌", "🚍", "🚎", "🚐", "🚑", "🚒", "🚓", "🚔", "🚨", "🚕", "🚖", "🚗", "🚘", "🚙", "🚚", "🚛", "🚜", "🚲", "🚏", "⛽️", 
      "🚧", "🚦", "🚥", "🚀", "🚁", "✈️", "💺", "⚓️", "🚢", "🚤", "⛵️", "🚡", "🚠", "🚟", "🛂", "🛃", "🛄", "🛅", "💴", "💶", "💷", "💵", "🗽", "🗿", "🌁", "🗼", "⛲️", "🏰", "🏯", "🌇", "🌆", "🌃", "🌉", "🏠", "🏡", "🏢", "🏬", "🏭", "🏣", "🏤", "🏥", "🏦", "🏨", "🏩", "💒", "⛪️", 
      "🏪", "🏫", "🇦🇺", "🇦🇹", "🇧🇪", "🇧🇷", "🇨🇦", "🇨🇱", "🇨🇳", "🇨🇴", "🇩🇰", "🇫🇮", "🇫🇷", "🇩🇪", "🇭🇰", "🇮🇳", "🇮🇩", "🇮🇪", "🇮🇱", "🇮🇹", "🇯🇵", "🇰🇷", "🇲🇴", "🇲🇾", "🇲🇽", "🇳🇱", "🇳🇿", "🇳🇴", "🇵🇭", "🇵🇱", "🇵🇹", "🇵🇷", "🇷🇺", "🇸🇦", 
      "🇸🇬", "🇿🇦", "🇪🇸", "🇸🇪", "🇨🇭", "🇹🇷", "🇬🇧", "🇺🇸", "🇦🇪", "🇻🇳", "⌚️", "📱", "📲", "💻", "⏰", "⏳", "⌛️", "📷", "📹", "🎥", "📺", "📻", "📟", "📞", "☎️", "📠", "💽", "💾", "💿", "📀", "📼", "🔋", "🔌", "💡", "🔦", "📡", "💳", "💸", "💰", "💎⌚️", "📱", "📲", 
      "💻", "⏰", "⏳", "⌛️", "📷", "📹", "🎥", "📺", "📻", "📟", "📞", "☎️", "📠", "💽", "💾", "💿", "📀", "📼", "🔋", "🔌", "💡", "🔦", "📡", "💳", "💸", "💰", "💎🚪", "🚿", "🛁", "🚽", "💈", "💉", "💊", "🔬", "🔭", "🔮", "🔧", "🔪", "🔩", "🔨", "💣", "🚬", "🔫", "🔖", "📰", "🔑", 
      "✉️", "📩", "📨", "📧", "📥", "📤", "📦", "📯", "📮", "📪", "📫", "📬", "📭", "📄", "📃", "📑", "📈", "📉", "📊", "📅", "📆", "🔅", "🔆", "📜", "📋", "📖", "📓", "📔", "📒", "📕", "📗", "📘", "📙", "📚", "📇", "🔗", "📎", "📌", "✂️", "📐", "📍", "📏", "🚩", "📁", "📂", "✒️", "✏️", 
      "📝", "🔏", "🔐", "🔒", "🔓", "📣", "📢", "🔈", "🔉", "🔊", "🔇", "💤", "🔔", "🔕", "💭", "💬", "🚸", "🔍", "🔎", "🚫", "⛔️", "📛", "🚷", "🚯", "🚳", "🚱", "📵", "🔞", "🉑", "🉐", "💮", "㊙️", "㊗️", "🈴", "🈵", "🈲", "🈶", "🈚️", "🈸", "🈺", "🈷", "🈹", "🈳", "🈂", "🈁", 
      "🈯️", "💹", "❇️", "✳️", "❎", "✅", "✴️", "📳", "📴", "🆚", "🅰", "🅱", "🆎", "🆑", "🅾", "🆘", "🆔", "🅿️", "🚾", "🆒", "🆓", "🆕", "🆖", "🆗", "🆙", "🏧", "♈️", "♉️", "♊️", "♋️", "♌️", "♍️", "♎️", "♏️", "♐️", "♑️", "♒️", "♓️", "🚻", "🚹", "🚺", "🚼", "♿️", "🚰", "🚭", "🚮", "▶️", "◀️", "🔼", "🔽", 
      "⏩", "⏪", "⏫", "⏬", "➡️", "⬅️", "⬆️", "⬇️", "↗️", "↘️", "↙️", "↖️", "↕️", "↔️", "🔄", "↪️", "↩️", "⤴️", "⤵️", "🔀", "🔁", "🔂", "#️⃣", "0️⃣", "1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣", "🔟", "🔢", "🔤", "🔡", "🔠", "ℹ️", "📶", "🎦", "🔣", "➕", "➖", "〰", "➗", "✖️", "✔️", 
      "🔃", "™", "©", "®", "💱", "💲", "➰", "➿", "〽️", "❗️", "❓", "❕", "❔", "‼️", "⁉️", "❌", "⭕️", "💯", "🔚", "🔙", "🔛", "🔝", "🔜", "🌀", "Ⓜ️", "⛎", "🔯", "🔰", "🔱", "⚠️", "♨️", "♻️", "💢", "💠", "♠️", "♣️", "♥️", "♦️", "☑️", "⚪️", "⚫️", "🔘", "🔴", "🔵", "🔺", "🔻", "🔸", "🔹", "🔶", 
      "🔷", "▪️", "▫️", "⬛️", "⬜️", "◼️", "◻️", "◾️", "◽️", "🔲", "🔳", "🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛", "🕜", "🕝", "🕞", "🕟", "🕠", "🕡", "🕢", "🕣", "🕤", "🕥", "🕦", "🕧", "🌡", "🌢", "🌣", "🌤", "🌥", "🌦", "🌧", "🌨", "🌩", "🌪", "🌫", "🌬", "🌶",  
      "🛌", "🛍", "🛎", "🛏", "🛠", "🛡", "🛢", "🛣", "🛤", "🛥", "🛦", "🛧", "🛨", "🛩", "🛪", "🛫", "🛬", "🛰", "🛱", "🛲", "🛳"] 
    regex_1 = /[\u{203C}\u{2049}\u{20E3}\u{2122}\u{2139}\u{2194}-\u{2199}\u{21A9}-\u{21AA}\u{231A}-\u{231B}\u{23E9}-\u{23EC}\u{23F0}\u{23F3}\u{24C2}\u{25AA}-\u{25AB}\u{25B6}\u{25C0}\u{25FB}-\u{25FE}\u{2600}-\u{2601}\u{260E}\u{2611}\u{2614}-\u{2615}\u{261D}\u{263A}\u{2648}-\u{2653}\u{2660}\u{2663}\u{2665}-\u{2666}\u{2668}\u{267B}\u{267F}\u{2693}\u{26A0}-\u{26A1}\u{26AA}-\u{26AB}\u{26BD}-\u{26BE}\u{26C4}-\u{26C5}\u{26CE}\u{26D4}\u{26EA}\u{26F2}-\u{26F3}\u{26F5}\u{26FA}\u{26FD}\u{2702}\u{2705}\u{2708}-\u{270C}\u{270F}\u{2712}\u{2714}\u{2716}\u{2728}\u{2733}-\u{2734}\u{2744}\u{2747}\u{274C}\u{274E}\u{2753}-\u{2755}\u{2757}\u{2764}\u{2795}-\u{2797}\u{27A1}\u{27B0}\u{2934}-\u{2935}\u{2B05}-\u{2B07}\u{2B1B}-\u{2B1C}\u{2B50}\u{2B55}\u{3030}\u{303D}\u{3297}\u{3299}\u{1F004}\u{1F0CF}\u{1F170}-\u{1F171}\u{1F17E}-\u{1F17F}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F1E7}-\u{1F1EC}\u{1F1EE}-\u{1F1F0}\u{1F1F3}\u{1F1F5}\u{1F1F7}-\u{1F1FA}\u{1F201}-\u{1F202}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F23A}\u{1F250}-\u{1F251}\u{1F300}-\u{1F320}\u{1F330}-\u{1F335}\u{1F337}-\u{1F37C}\u{1F380}-\u{1F393}\u{1F3A0}-\u{1F3C4}\u{1F3C6}-\u{1F3CA}\u{1F3E0}-\u{1F3F0}\u{1F400}-\u{1F43E}\u{1F440}\u{1F442}-\u{1F4F7}\u{1F4F9}-\u{1F4FC}\u{1F500}-\u{1F507}\u{1F509}-\u{1F53D}\u{1F550}-\u{1F567}\u{1F5FB}-\u{1F640}\u{1F645}-\u{1F64F}\u{1F680}-\u{1F68A}]/
    regex_2 = /[\u{00A9}\u{00AE}\u{203C}\u{2049}\u{2122}\u{2139}\u{2194}-\u{2199}\u{21A9}-\u{21AA}\u{231A}-\u{231B}\u{2328}\u{23CF}\u{23E9}-\u{23F3}\u{23F8}-\u{23FA}\u{24C2}\u{25AA}-\u{25AB}\u{25B6}\u{25C0}\u{25FB}-\u{25FE}\u{2600}-\u{2604}\u{260E}\u{2611}\u{2614}-\u{2615}\u{2618}\u{261D}\u{2620}\u{2622}-\u{2623}\u{2626}\u{262A}\u{262E}-\u{262F}\u{2638}-\u{263A}\u{2648}-\u{2653}\u{2660}\u{2663}\u{2665}-\u{2666}\u{2668}\u{267B}\u{267F}\u{2692}-\u{2694}\u{2696}-\u{2697}\u{2699}\u{269B}-\u{269C}\u{26A0}-\u{26A1}\u{26AA}-\u{26AB}\u{26B0}-\u{26B1}\u{26BD}-\u{26BE}\u{26C4}-\u{26C5}\u{26C8}\u{26CE}-\u{26CF}\u{26D1}\u{26D3}-\u{26D4}\u{26E9}-\u{26EA}\u{26F0}-\u{26F5}\u{26F7}-\u{26FA}\u{26FD}\u{2702}\u{2705}\u{2708}-\u{270D}\u{270F}\u{2712}\u{2714}\u{2716}\u{271D}\u{2721}\u{2728}\u{2733}-\u{2734}\u{2744}\u{2747}\u{274C}\u{274E}\u{2753}-\u{2755}\u{2757}\u{2763}-\u{2764}\u{2795}-\u{2797}\u{27A1}\u{27B0}\u{27BF}\u{2934}-\u{2935}\u{2B05}-\u{2B07}\u{2B1B}-\u{2B1C}\u{2B50}\u{2B55}\u{3030}\u{303D}\u{3297}\u{3299}\u{1F004}\u{1F0CF}\u{1F170}-\u{1F171}\u{1F17E}-\u{1F17F}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F201}-\u{1F202}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F23A}\u{1F250}-\u{1F251}\u{1F300}-\u{1F321}\u{1F324}-\u{1F393}\u{1F396}-\u{1F397}\u{1F399}-\u{1F39B}\u{1F39E}-\u{1F3F0}\u{1F3F3}-\u{1F3F5}\u{1F3F7}-\u{1F4FD}\u{1F4FF}-\u{1F53D}\u{1F549}-\u{1F54E}\u{1F550}-\u{1F567}\u{1F56F}-\u{1F570}\u{1F573}-\u{1F579}\u{1F587}\u{1F58A}-\u{1F58D}\u{1F590}\u{1F595}-\u{1F596}\u{1F5A5}\u{1F5A8}\u{1F5B1}-\u{1F5B2}\u{1F5BC}\u{1F5C2}-\u{1F5C4}\u{1F5D1}-\u{1F5D3}\u{1F5DC}-\u{1F5DE}\u{1F5E1}\u{1F5E3}\u{1F5EF}\u{1F5F3}\u{1F5FA}-\u{1F64F}\u{1F680}-\u{1F6C5}\u{1F6CB}-\u{1F6D0}\u{1F6E0}-\u{1F6E5}\u{1F6E9}\u{1F6EB}-\u{1F6EC}\u{1F6F0}\u{1F6F3}\u{1F910}-\u{1F918}\u{1F980}-\u{1F984}\u{1F9C0}]/
   
    vname_emoji_strip_1 = vname.gsub regex_1, ''
    vname_emoji_strip_2 = vname_emoji_strip_1.gsub regex_2, '' 

    if not vname
      result = false
    #genuine locations have proper text formatting 
    elsif vname.downcase == vname || vname.upcase == vname
      result = false
    #check for emojis
    elsif vname.length != vname_emoji_strip_2.length
      result = false
    elsif vname.strip.last == "."
      result = false
    elsif (vname.downcase.include? "www.") || (vname.downcase.include? ".com") || (vname.downcase.include? "http://") || (vname.downcase.include? "https://")
      result = false
    elsif (vname.downcase.include? "|") || (vname.downcase.include? "#") || (vname.downcase.include? ";") || (vname.downcase.include? "/")
      result = false
    elsif (vname.downcase.include? "snapchat") || (vname.downcase.include? "whatsapp") || (vname.downcase.include? "viber") || (vname.downcase.include? "sms")
      result = false
    elsif (vname.downcase.include? ",") || (vname.downcase.include? "(") || (vname.downcase.include? ")")
      result = false
    elsif (vname.downcase.split & emoji_and_symbols).count != 0
      result = false
    elsif vname != vname.titlecase
      result = false
    else
      result = true
    end
    return result
  end

  def Venue.scrub_venue_name(raw_name, city)
    #Many Instagram names are contaminated with extra information inputted by the user, i.e "Concert @ Madison Square Garden"
    if raw_name != nil && city != nil
      lower_raw_name = raw_name.downcase 
      lower_city = city.downcase

      if lower_raw_name.include?("@") == true
        lower_raw_name = lower_raw_name.partition("@").last.strip
      end

      if lower_raw_name.include?(" at ") == true
        lower_raw_name = lower_raw_name.partition(" at ").last.strip.capitalize
      end

      if (lower_city != nil && lower_city != "" && lower_city != " ") and lower_raw_name.include?("#{lower_city}") == true
        lower_raw_name = lower_raw_name.partition("#{lower_city}").first.strip
      end

      clean_name = lower_raw_name.titleize
      return clean_name || raw_name
    else
      raw_name
    end
  end

  def Venue.clear_stop_words(venue_name)
    lower_venue_name = venue_name.downcase
    stop_words = ["the", "a", "cafe", "café", "restaurant", "club", "bar", "hotel", "downtown", "updtown", "midtown", "park", "national", "of", "at", "university", ",", "."]
    pattern = /\b(?:#{ Regexp.union(stop_words).source })\b/    
    lower_venue_name[pattern]
    lower_venue_name.gsub(pattern, '').squeeze(' ').strip.titleize
  end

  def Venue.name_for_comparison(raw_venue_name, city)
    scrubbed_name = Venue.scrub_venue_name(raw_venue_name, city)
    stop_word_cleared_name = Venue.clear_stop_words(scrubbed_name)
  end

  def Venue.validate_venue(venue_name, venue_lat, venue_long, venue_instagram_location_id, origin_vortex)
    #Used to establish if a location tied to an Instagram is legitimate and not a fake, "Best Place Ever" type one.
    #Returns a venue object if location is valid, otherwise nil. Primary check occurs through a Froursquare lookup.
    if venue_name != nil and Venue.name_is_proper?(venue_name)
      lytit_venue_lookup = Venue.fetch_venues_for_instagram_pull(venue_name, venue_lat, venue_long, venue_instagram_location_id, origin_vortex)

      if lytit_venue_lookup == nil
        foursquare_venue = Venue.foursquare_venue_lookup(venue_name, venue_lat, venue_long, origin_vortex.city)
          #no corresponding venue found in Foursquare database
        if foursquare_venue == nil || foursquare_venue == "F2 ERROR"
          return nil
        else
          #for major US cities we only deal with verified venues
          major_cities = ["United States"]
          if major_cities.include? origin_vortex.country == true && foursquare_venue.verified == false
            return nil
          else
            new_lytit_venue = Venue.create_new_db_entry(foursquare_venue.name, nil, origin_vortex.city, nil, nil, nil, nil, venue_lat, venue_long, venue_instagram_location_id, origin_vortex)
            new_lytit_venue.update_columns(foursquare_id: foursquare_venue.id)
            new_lytit_venue.update_columns(verified: true)
            new_lytit_venue.set_hours
            InstagramLocationIdLookup.delay.create!(:venue_id => new_lytit_venue.id, :instagram_location_id => venue_instagram_location_id)
            return new_lytit_venue
          end
        end
      else
        if lytit_venue_lookup.verified == true
          return lytit_venue_lookup
        else
          lytit_venue_lookup.delete
          return nil
        end
      end
    else
      nil
    end
  end

  def Venue.foursquare_venue_lookup(venue_name, venue_lat, venue_long, origin_city)
    client = Foursquare2::Client.new(:client_id => '35G1RAZOOSCK2MNDOMFQ0QALTP1URVG5ZQ30IXS2ZACFNWN1', :client_secret => 'ZVMBHYP04JOT2KM0A1T2HWLFDIEO1FM3M0UGTT532MHOWPD0', :api_version => '20120610')
    foursquare_search_results = client.search_venues(:ll => "#{venue_lat},#{venue_long}", :query => Venue.name_for_comparison(venue_name.downcase, origin_city), :radius => 250) rescue "F2 ERROR"
    if foursquare_search_results != "F2 ERROR" and (foursquare_search_results.first != nil and foursquare_search_results.first.last.count > 0)
      foursquare_venue = foursquare_search_results.first.last.first
      if foursquare_venue != nil and (venue_name.downcase.include?(foursquare_venue.name.downcase) == false && (foursquare_venue.name.downcase).include?(venue_name.downcase) == false)
        require 'fuzzystringmatch'
        jarow = FuzzyStringMatch::JaroWinkler.create( :native )
        overlap = venue_name.downcase.split & foursquare_venue.name.downcase.split
        jarow_winkler_proximity = p jarow.getDistance(Venue.name_for_comparison(venue_name.downcase, origin_city), Venue.name_for_comparison(foursquare_venue.name.downcase, origin_city))#venue_name.downcase.gsub(overlap, "").trim, foursquare_venue.name.downcase.gsub(overlap, "").trim)
        if jarow_winkler_proximity < 0.75
          foursquare_venue = nil
          for entry in foursquare_search_results.first.last
            overlap = venue_name.downcase.split & entry.name.downcase.split
            jarow_winkler_proximity = p jarow.getDistance(Venue.name_for_comparison(venue_name.downcase, origin_city), Venue.name_for_comparison(entry.name.downcase, origin_city))#(venue_name.downcase.gsub(overlap, "").trim, entry.name.downcase.gsub(overlap, "").trim)
            if jarow_winkler_proximity >= 0.75
              foursquare_venue = entry
            end
          end
        end
      end

      return foursquare_venue
    else
      if foursquare_search_results == "F2 ERROR"
        return "F2 ERROR"
      else
        return nil
      end
    end
  end

  def foursquare_venue
    client = Foursquare2::Client.new(:client_id => '35G1RAZOOSCK2MNDOMFQ0QALTP1URVG5ZQ30IXS2ZACFNWN1', :client_secret => 'ZVMBHYP04JOT2KM0A1T2HWLFDIEO1FM3M0UGTT532MHOWPD0', :api_version => '20120610')
    client.venue(self.foursquare_id)
  end

  def instagram_venue
    Instagram.location_search(self.instagram_location_id)
  end

  def self.fetch_venues_for_instagram_pull(vname, lat, long, inst_loc_id, vortex)
    #Reference LYTiT Instagram Location Id Database
    inst_id_lookup = InstagramLocationIdLookup.find_by_instagram_location_id(inst_loc_id)

    vname = scrub_venue_name(vname, vortex.city)

    if vname != nil && vname != ""
      if inst_id_lookup.try(:venue) != nil && inst_loc_id.to_i != 0
        result = inst_id_lookup.venue
      else
        #Check if there is a direct name match in proximity
        center_point = [lat, long]
        search_box = Geokit::Bounds.from_point_and_radius(center_point, 0.3, :units => :kms)

        name_lookup = Venue.in_bounds(search_box).fuzzy_name_search(vname, 0.7).first
        if name_lookup == nil
          name_lookup = Venue.search(vname, search_box, nil).first
        end

        if name_lookup != nil
          result = name_lookup
        else
          result = nil
        end
      end
      return result
    else
      return nil
    end
  end

  def set_instagram_location_id(search_radius)
    #Set-up of tools to be used
    require 'fuzzystringmatch'
    jarow = FuzzyStringMatch::JaroWinkler.create( :native )    
    if search_radius == nil
      search_radius = 100
    end
    search_hash = Hash.new #has the from [match_strength] => instagram_location_id where match_strength is a function of a returned instagrams
    wide_area_search = false
    occurence_multiplier = 1.15 #if a location shows up more than once in the instagram pull return statement and is of certain string closeness to an entry we amplify it match_score
    
    #We must identify landmarks, parks, etc. because of their large areas and pull instagrams from a bigger radius. Most of these types
    #of locations will not have a specific address, city or particularly postal code because of their size.

    if self.name.downcase.include?("university") || self.name.downcase.include?("park")
      wide_area_search = true
      nearby_instagram_content = Instagram.media_search(latitude, longitude, :distance => 200, :count => 100)
    else
      #Dealing with an establishment so can afford a smaller pull radius.
      nearby_instagram_content = Instagram.media_search(latitude, longitude, :distance => search_radius, :count => 100)
    end

    if nearby_instagram_content.count > 0
      for instagram in nearby_instagram_content
        if instagram.location.name != nil
          puts("#{instagram.location.name} (#{instagram.location.id})")
          #when working with proper names words like "the" and "a" hinder accuracy    
          instagram_location_name_clean = Venue.scrub_venue_name(instagram.location.name.downcase, city)
          venue_name_clean = Venue.scrub_venue_name(self.name.downcase, city)
        
          jarow_winkler_proximity = p jarow.getDistance(instagram_location_name_clean, venue_name_clean)

          if jarow_winkler_proximity >= 0.7 && ((self.name.downcase.include?("park") == true && instagram.location.name.downcase.include?("park")) == true || (self.name.downcase.include?("park") == false && instagram.location.name.downcase.include?("park") == false))
            if not search_hash[instagram.location.id]
              search_hash[instagram.location.id] = jarow_winkler_proximity
            else
              previous_score = search_hash[instagram.location.id]
              search_hash[instagram.location.id] = previous_score * occurence_multiplier
            end
          
          end
        end
      end

      if search_hash.count > 0
        best_location_match_id = search_hash.max_by{|k,v| v}.first
        self.update_columns(instagram_location_id: best_location_match_id)
        if InstagramLocationIdLookup.find_by_instagram_location_id(best_location_match_id) == nil
          inst_location_id_tracker_lookup_entry = InstagramLocationIdLookup.new(:venue_id => self.id, :instagram_location_id => best_location_match_id)
          inst_location_id_tracker_lookup_entry.save
        end

        #the proper instagram location id has been determined now we go back and traverse the pulled instagrams to filter out the instagrams
        #we need and create venue comments
        venue_comments_created = 0
        venue_instagrams = []
        for instagram in nearby_instagram_content
          if instagram.location.id == self.instagram_location_id && DateTime.strptime("#{instagram.created_time}",'%s') >= Time.now - 24.hours
            venue_instagrams << instagram.to_hash
          end
        end
        VenueComment.delay.convert_bulk_instagrams_to_vcs(venue_instagrams, self)

        #if little content is offered on the geo pull make a venue specific pull
        if venue_instagrams.count < 3
          puts ("Making a venue get instagrams calls!")
          venue_instagrams = self.get_instagrams(true)
          #venue_instagrams.concat(self.get_instagrams(true))
          #venue_instagrams.flatten!
          #to preserve API calls if we make a call now a longer period must pass before making another pull of a venue's instagram comments
          self.update_columns(last_instagram_pull_time: Time.now + 15.minutes)
        else
          self.update_columns(last_instagram_pull_time: Time.now)
        end
      else
        #recursive call with slightly bigger radius for venue searches
        if search_radius != 250 && wide_area_search != true
          set_instagram_location_id(250)
        else
          self.update_columns(instagram_location_id: 0)
        end
      end
    else
      #recursive call with slightly bigger radius for venue searches
      if search_radius != 250 && wide_area_search != true
        set_instagram_location_id(250)
      else
        self.update_columns(instagram_location_id: 0)
      end
    end

    if venue_instagrams != nil and venue_instagrams.first.nil? == false
      venue_instagrams.sort_by!{|instagram| -(instagram["created_time"].to_i)}
    else
      venue_instagrams = []
    end

    return venue_instagrams
  end


  #Instagram API locational content pulls. The min_id_consideration variable is used because we also call get_instagrams sometimes when setting an instagram location id (see bellow) and thus 
  #need access to all recent instagrams
  def get_instagrams(day_pull)
    last_instagram_id = nil

    instagrams = instagram_location_ping(day_pull, false)

    if instagrams.count > 0
      #instagrams.sort_by!{|instagram| -(instagram.created_time.to_i)}
      #instagrams.map!(&:to_hash)
      VenueComment.delay.convert_bulk_instagrams_to_vcs(instagrams, self)
    else
      instagrams = []
    end

    return instagrams
  end

  def instagram_location_ping(day_pull, hourly_pull)
    instagram_access_token_obj = InstagramAuthToken.where("is_valid IS TRUE").sample(1).first    
    if instagram_access_token_obj == nil
      client = Instagram.client
    else
      instagram_access_token = instagram_access_token_obj.token
      instagram_access_token_obj.increment!(:num_used, 1)
      client = Instagram.client(:access_token => instagram_access_token)
    end

    instagrams = []
    if (day_pull == true && hourly_pull == false) || (last_instagram_pull_time == nil or last_instagram_pull_time <= Time.now - 24.hours)
      instagrams = client.location_recent_media(self.instagram_location_id, :min_timestamp => (Time.now-24.hours).to_time.to_i).map(&:to_hash) rescue self.rescue_instagram_api_call(instagram_access_token, day_pull, false).map(&:to_hash)
      self.update_columns(last_instagram_pull_time: Time.now)
    elsif hourly_pull == true 
      instagrams = client.location_recent_media(self.instagram_location_id, :min_timestamp => (Time.now-1.hour).to_time.to_i) rescue self.rescue_instagram_api_call(instagram_access_token, false, true)
      self.update_columns(last_instagram_pull_time: Time.now)
    else
      instagrams = client.location_recent_media(self.instagram_location_id, :min_id => self.last_instagram_post, :min_timestamp => (Time.now-24.hours).to_time.to_i).map(&:to_hash) rescue self.rescue_instagram_api_call(instagram_access_token, day_pull, false)
      self.update_columns(last_instagram_pull_time: Time.now)
    end

    if instagrams != nil and instagrams.first != nil
      return instagrams
    else
      puts "No Instagrams"
      return []
    end
  end

  def rescue_instagram_api_call(invalid_instagram_access_token, day_pull, hourly_pull)
    if invalid_instagram_access_token != nil
      InstagramAuthToken.find_by_token(invalid_instagram_access_token).update_columns(is_valid: false)
    end

    if day_pull == true
      Instagram.location_recent_media(self.instagram_location_id, :min_timestamp => (Time.now-24.hours).to_time.to_i)
    else
      if self.last_instagram_post != nil && hourly_pull == false
        Instagram.location_recent_media(self.instagram_location_id, :min_id => self.last_instagram_post, :min_timestamp => (Time.now-24.hours).to_time.to_i).map(&:to_hash) rescue []
      else
        if hourly_pull == true
          Instagram.location_recent_media(self.instagram_location_id, :min_timestamp => (Time.now-1.hour).to_time.to_i) rescue []
        else
          Instagram.location_recent_media(self.instagram_location_id, :min_timestamp => (Time.now-24.hours).to_time.to_i).map(&:to_hash) rescue []
        end
      end
    end
  end

  def self.get_comments(venue_ids)    
    if venue_ids.count > 1
    #returning cluster comments which is just a pull of all avaliable underlying venue comments
      return VenueComment.where("venue_id IN (?)", venue_ids).order("time_wrapper desc")
    else
    #dealing with an individual venue which could require an instagram pull
      venue = Venue.find_by_id(venue_ids.first)

      new_instagrams = []
      new_instagrams = venue.update_comments

      #new_instagrams.sort_by{|instagram| instagram["created_time"].reverse}
      if new_instagrams != nil and new_instagrams.first.is_a?(Hash) == true
        lytit_vcs = venue.venue_comments.order("time_wrapper DESC")
        if lytit_vcs.first != nil
          new_instagrams.concat(lytit_vcs)
        end
        #total_media.flatten!
        return Kaminari.paginate_array(new_instagrams) #Kaminari.paginate_array(total_media.sort_by{|post| VenueComment.implicit_created_at(post)}.reverse)
      else
        return venue.venue_comments.order("time_wrapper DESC")
      end
    end
  end

  def update_comments
    if self.is_open?
      instagram_refresh_rate = 10 #minutes
      instagram_venue_id_ping_rate = 1 #days      

      if self.instagram_location_id != nil && self.last_instagram_pull_time != nil
        #try to establish instagram location id if previous attempts failed every 1 day
        if self.instagram_location_id == 0 
          if self.latest_posted_comment_time != nil and ((Time.now - instagram_venue_id_ping_rate.days >= self.latest_posted_comment_time) && (Time.now - (instagram_venue_id_ping_rate/2.0).days >= self.last_instagram_pull_time))
            new_instagrams = self.set_instagram_location_id(100)
            self.update_columns(last_instagram_pull_time: Time.now)
          else
            new_instagrams = []
          end
        elsif self.latest_posted_comment_time != nil and (Time.now - instagram_venue_id_ping_rate.days >= self.last_instagram_pull_time)
            new_instagrams = self.set_instagram_location_id(100)
            self.update_columns(last_instagram_pull_time: Time.now)
        else
          if ((Time.now - instagram_refresh_rate.minutes) >= self.last_instagram_pull_time)
            new_instagrams = self.get_instagrams(false)
          else
            new_instagrams = []
          end
        end
      else
        new_instagrams = self.set_instagram_location_id(150)
        self.update_columns(last_instagram_pull_time: Time.now)
      end
      new_instagrams
    else
      []
    end
  end


  def instagram_pull_check
    instagram_refresh_rate = 15 #minutes
    instagram_venue_id_ping_rate = 1 #days

    if self.instagram_location_id != nil && self.last_instagram_pull_time != nil
      #try to establish instagram location id if previous attempts failed every 1 day
      if self.instagram_location_id == 0 
        if ((Time.now - instagram_venue_id_ping_rate.minutes) >= self.last_instagram_pull_time)
          self.set_instagram_location_id(100)
          self.update_columns(last_instagram_pull_time: Time.now)
        end
      else
        #if 5 minutes remain till the instagram refresh rate pause is met we make a delayed called since the content in the VP is fresh enough and we do not want to 
        #keep the client waiting for an Instagram API response
        if ((Time.now - (instagram_refresh_rate-5).minutes) > self.last_instagram_pull_time) && ((Time.now - instagram_refresh_rate.minutes) < self.last_instagram_pull_time)
          new_media_created = self.delay.get_instagrams(false)
        end

        #if more than or equal to instagram refresh rate pause time has passed then we make the client wait a bit longer but deliver fresh content (no delayed job used)
        if ((Time.now - instagram_refresh_rate.minutes) >= self.last_instagram_pull_time)
            new_media_created = self.get_instagrams(false)
        end
      end
    else
      if self.instagram_location_id == nil
        self.set_instagram_location_id(100)
      elsif self.instagram_location_id != 0
        new_media_created = self.get_instagrams(false)
      else
        new_media_created = false
      end
    end
  end

  def self.instagram_content_pull(lat, long)
    if lat != nil && long != nil
      
      surrounding_lyts_radius = 10000 * 1/1000
      if not Venue.within(surrounding_lyts_radius.to_f, :units => :kms, :origin => [lat, long]).where("rating > 0").any? #Venue.within(Venue.meters_to_miles(surrounding_lyts_radius.to_i), :origin => [lat, long]).where("rating > 0").any?
        new_instagrams = Instagram.media_search(lat, long, :distance => 5000, :count => 100, :min_timestamp => (Time.now-24.hours).to_time.to_i)

        #If more than 70 Instagram in area over the past day we do a vortex proximity check to see if one needs to be dropped
        if new_instagrams.count > 70
          InstagramVortex.check_nearby_vortex_existence(lat, long)
        end

        for instagram in new_instagrams
          #VenueComment.convert_instagram_to_vc(instagram, nil, nil)
          VenueComment.create_vc_from_instagram(instagram.to_hash, nil, nil, true)
        end
      end
    end

  end

  def self.initial_list_instagram_pull(initial_list_venue_ids)
    venues = Venue.where("id IN (#{initial_list_venue_ids}) AND instagram_location_id IS NOT NULL").limit(10)
    for venue in venues
      if venue.latest_posted_comment_time < (Time.now - 1.hour)
        #pull insts from instagram and convert immediately to vcs
        instagrams = venue.instagram_location_ping(false, true)
        if instagrams.length > 0
          instagrams.sort_by!{|instagram| -(instagram.created_time.to_i)} rescue nil
          venue.set_last_venue_comment_details(instagrams.first)
          VenueComment.delay.map_instagrams_to_hashes_and_convert(instagrams)
        end
        #set venue's last vc fields to latest instagram
        #venue.set_last_venue_comment_details(vc)        
      end
    end
  end

  def set_last_venue_comment_details(vc)
    if vc != nil
      if vc.class.name == "VenueComment"
        self.update_columns(latest_post_details: vc.as_json)

        self.update_columns(venue_comment_id: vc.id)
        self.update_columns(venue_comment_instagram_id: vc.instagram_id)
        self.update_columns(venue_comment_created_at: vc.time_wrapper)
        self.update_columns(venue_comment_content_origin: vc.content_origin)
        self.update_columns(venue_comment_thirdparty_username: vc.thirdparty_username)
        self.update_columns(media_type: vc.media_type)
        self.update_columns(image_url_1: vc.image_url_1)
        self.update_columns(image_url_2: vc.image_url_2)
        self.update_columns(image_url_3: vc.image_url_3)
        self.update_columns(video_url_1: vc.video_url_1)
        self.update_columns(video_url_2: vc.video_url_2)
        self.update_columns(video_url_3: vc.video_url_3)
      else
        if vc.type == "video"
          video_url_1 = vc.videos.try(:low_bandwith).try(:url)
          video_url_2 = vc.videos.try(:low_resolution).try(:url)
          video_url_3 = vc.videos.try(:standard_resolution).try(:url)
        else
          video_url_1 = nil
          video_url_2 = nil
          video_url_3 = nil
        end
        latest_post_hash = {}
        latest_post_hash["id"] = nil
        latest_post_hash["instagram_id"] = vc.id
        latest_post_hash["created_at"] = DateTime.strptime("#{vc.created_time}",'%s')
        latest_post_hash["content_origin"] = "instagram"
        latest_post_hash["thirdparty_username"] = vc.user.username
        latest_post_hash["media_type"] = vc.type
        latest_post_hash["image_url_1"] = vc.images.try(:thumbnail).try(:url)
        latest_post_hash["image_url_2"] = vc.images.try(:low_resolution).try(:url)
        latest_post_hash["image_url_3"] = vc.images.try(:standard_resolution).try(:url)
        latest_post_hash["video_url_1"] = video_url_1
        latest_post_hash["video_url_2"] = video_url_2
        latest_post_hash["video_url_3"] = video_url_3
        self.update_columns(latest_post_details: latest_post_hash)

        self.update_columns(venue_comment_id: nil)
        self.update_columns(venue_comment_instagram_id: vc.id)
        self.update_columns(venue_comment_created_at: DateTime.strptime("#{vc.created_time}",'%s'))
        self.update_columns(venue_comment_content_origin: "instagram")
        self.update_columns(venue_comment_thirdparty_username: vc.user.username)
        self.update_columns(media_type: vc.type)
        self.update_columns(image_url_1: vc.images.try(:thumbnail).try(:url))
        self.update_columns(image_url_2: vc.images.try(:low_resolution).try(:url))
        self.update_columns(image_url_3: vc.images.try(:standard_resolution).try(:url))
        self.update_columns(video_url_1: video_url_1)
        self.update_columns(video_url_2: video_url_2)
        self.update_columns(video_url_3: video_url_3)
      end
    end
  end
  #----------------------------------------------------------------------------->


  #IV. Additional/Misc Functionalities ------------------------------------------->
  #determines the type of venue, ie, country, state, city, neighborhood, or just a regular establishment.
  def last_post_time
    if latest_posted_comment_time != nil
      (Time.now - latest_posted_comment_time)
    else
      nil
    end
  end

  def type
    v_address = address || ""
    v_city = city || ""
    v_state = state || ""
    v_country = country || ""

    if postal_code == nil or postal_code == ""
      vpostal_code = 0
    else
      vpostal_code = postal_code
    end

    if name == v_country && (v_address == "" && v_city == "") && (v_state == "" && vpostal_code.to_i == 0)
      type = 4 #country
    elsif (name.length == 2 && v_address == "") && (v_city == "" && vpostal_code.to_i == 0)
      type = 3 #state
    elsif ((name[0..(name.length-5)] == v_city && v_country == "United States") || (name == v_city && v_country != "United States")) && (v_address == "")
      type = 2 #city
    else
      type = 1 #establishment
    end

    return type
  end

  def menu_link=(val)
    if val.present?
      unless (val.start_with?("http://") or val.start_with?("https://"))
        val = "http://#{val}"
      end
    else
      val = nil
    end
    write_attribute(:menu_link, val)
  end

  def has_menue?
    if menue.menu_section_items.count = 0
      return false
    else
      return true
    end
  end

  def to_param
    [id, name.parameterize].join("-")
  end

  def messages
    venue_messages
  end

  def visible_venue_comments
    ids = FlaggedComment.select("count(*) as count, venue_comment_id").joins(:venue_comment).where(:venue_comments => {:venue_id => self.id}).group("flagged_comments.venue_comment_id").collect{|a| a.venue_comment_id if a.count >= 50}.uniq.compact
    unless ids.present?
      ids = [-1]
    end
    venue_comments.where("venue_comments.id NOT IN (?)", ids)
  end

  def self.near_locations(lat, long)
    radius = 400.0 * 1/1000
    surroundings = Venue.within(radius.to_i, :units => :kms, :origin => [lat, long]).where("has_been_voted_at = TRUE AND is_address = FALSE").order('distance ASC limit 10')
    #Venue.within(Venue.meters_to_miles(meter_radius.to_i), :origin => [lat, long]).where("has_been_voted_at = TRUE AND is_address = FALSE").order('distance ASC limit 10')
  end

  def cord_to_city
    query = self.latitude.to_s + "," + self.longitude.to_s
    result = Geocoder.search(query).first 
    result_city = result.city || result.county
    result_city.slice!(" County")
    self.update_columns(city: result_city)
    return result_city
  end

  def Venue.reverse_geo_city_lookup(lat, long)
    query = lat.to_s + "," + long.to_s
    result = Geocoder.search(query).first 
    city = result.city
=begin    
    city = result.city || result.county
    if city == nil
      city = result.state
    end
    city.slice!(" County")
=end
  end

  def self.reverse_geo_country_lookup(lat, long)
    query = lat.to_s + "," + long.to_s
    result = Geocoder.search(query).first 
    country = result.country
  end

  def get_city_implicitly
    result = city || cord_to_city rescue nil
  end

  def self.miles_to_meters(miles)
    miles * 1609.34
  end

  def self.meters_to_miles(meter)
    meter * 0.000621371
  end

  def self.reset_venues
    Venue.update_all(rating: nil)
    Venue.update_all(r_up_votes: 1.0)
    Venue.update_all(r_down_votes: 1.0)
    Venue.update_all(color_rating: -1.0)
    VenueComment.where("content_origin = ?", "instagram").delete_all
    MetaData.delete_all
    LytSphere.delete_all
    LytitVote.where("user_id IS NULL").delete_all
  end

  def self.reset_venue_lyt_spheres
    target_venues = Venue.all
    for v in target_venues
      if v.latitude < 0 && v.longitude >= 0
        quadrant = "a"
      elsif v.latitude < 0 && v.longitude < 0
        quadrant = "b"
      elsif v.latitude >= 0 && v.longitude < 0
        quadrant = "c"
      else
        quadrant = "d"
      end
      new_l_sphere = quadrant+(v.latitude.round(1).abs).to_s+(v.longitude.round(1).abs).to_s
      v.update_columns(l_sphere: new_l_sphere)
    end
  end

  def self.set_is_address_and_votes_received
    target_venues = Venue.all
    for v in target_venues
      if v.address != nil && v.name != nil
        if v.address.gsub(" ","").gsub(",", "") == v.name.gsub(" ","").gsub(",", "")
          v.update_columns(is_address: true)
        end
      end

      if v.lytit_votes.count > 0
        v.update_columns(has_been_voted_at: true)
      end
    end
  end
  #------------------------------------------------------------------------------>

  #V. Twitter Functionality ----------------------------------------------------->
  def venue_twitter_tweets
    time_out_minutes = 5
    if self.last_twitter_pull_time == nil or (Time.now - self.last_twitter_pull_time > time_out_minutes.minutes)
      
      new_venue_tweets = self.update_tweets(true)

      total_venue_tweets = []
      if new_venue_tweets != nil
        #total_venue_tweets << new_venue_tweets.sort_by{|tweet| Tweet.popularity_score_calculation(tweet.user.followers_count, tweet.retweet_count, tweet.favorite_count)}
        total_venue_tweets << new_venue_tweets.sort_by{|tweet_1, tweet_2| Tweet.sort(tweet_1, tweet_2)}
      end
      total_venue_tweets << Tweet.where("venue_id = ? AND (NOW() - created_at) <= INTERVAL '1 DAY'", id).order("timestamp DESC").order("popularity_score DESC")
      total_venue_tweets.flatten!.compact!
      return Kaminari.paginate_array(total_venue_tweets)
    else
      Tweet.where("venue_id = ? AND (NOW() - created_at) <= INTERVAL '1 DAY'", id).order("timestamp DESC").order("popularity_score DESC")
    end
  end
  #total_venue_tweets << new_venue_tweets.sort_by{|tweet_1, tweet_2| Venue.tweet_sorting(tweet_1, tweet_2)}

  def self.cluster_twitter_tweets(cluster_lat, cluster_long, zoom_level, map_scale, venue_ids)    
    cluster = ClusterTracker.check_existence(cluster_lat, cluster_long, zoom_level)
    cluster_venue_ids = venue_ids.split(',').map(&:to_i)
    radius = map_scale.to_f/2.0 * 1/1000#Venue.meters_to_miles(map_scale.to_f/2.0)
    cluster_center_point = [cluster_lat, cluster_long]
    search_box = Geokit::Bounds.from_point_and_radius(cluster_center_point, radius, :units => :kms)

    time_out_minutes = 3
    if cluster.last_twitter_pull_time == nil or cluster.last_twitter_pull_time > Time.now - time_out_minutes.minutes
      cluster.update_columns(last_twitter_pull_time: Time.now)
      client = Twitter::REST::Client.new do |config|
        config.consumer_key        = '286I5Eu8LD64ApZyIZyftpXW2'
        config.consumer_secret     = '4bdQzIWp18JuHGcKJkTKSl4Oq440ETA636ox7f5oT0eqnSKxBv'
        config.access_token        = '2846465294-QPuUihpQp5FjOPlKAYanUBgRXhe3EWAUJMqLw0q'
        config.access_token_secret = 'mjYo0LoUnbKT4XYhyNfgH4n0xlr2GCoxBZzYyTPfuPGwk'
      end

      query = ""
      tags = MetaData.cluster_top_meta_tags(venue_ids).to_a      
      tags.each{|tag| query+=(tag.first.last+" OR ") if tag.first.last != nil || tag.first.last != ""}      
      query.chomp!(" OR ")

      tag_query_tweets = client.search(query+" -rt", result_type: "recent", geocode: "#{cluster_lat},#{cluster_long},#{radius}km").take(20).collect.to_a rescue nil      

      if tag_query_tweets != nil && tag_query_tweets.count > 0
        #tag_query_tweets.sort_by!{|tweet| Tweet.popularity_score_calculation(tweet.user.followers_count, tweet.retweet_count, tweet.favorite_count)}      
        tag_query_tweets.sort_by{|tweet_1, tweet_2| Tweet.sort(tweet_1, tweet_2)}
        Tweet.delay.bulk_conversion(tag_query_tweets, nil, cluster_lat, cluster_long, zoom_level, map_scale)
        tag_query_tweets << Tweet.in_bounds(search_box).where("associated_zoomlevel >= ? AND (NOW() - created_at) <= INTERVAL '1 DAY'", zoom_level).order("timestamp DESC").order("popularity_score DESC")
        total_cluster_tweets = tag_query_tweets.flatten.compact
        return Kaminari.paginate_array(total_cluster_tweets)
      else
        total_cluster_tweets = Tweet.in_bounds(search_box).where("associated_zoomlevel >= ? AND (NOW() - created_at) <= INTERVAL '1 DAY'", zoom_level).order("timestamp DESC").order("popularity_score DESC")
        return total_cluster_tweets
      end      
    else
      Tweet.in_bounds(search_box).where("associated_zoomlevel >= ? AND (NOW() - created_at) <= INTERVAL '1 DAY'", zoom_level).order("timestamp DESC").order("popularity_score DESC")
    end
  end

  def update_tweets(delay_conversion)
      client = Twitter::REST::Client.new do |config|
        config.consumer_key        = '286I5Eu8LD64ApZyIZyftpXW2'
        config.consumer_secret     = '4bdQzIWp18JuHGcKJkTKSl4Oq440ETA636ox7f5oT0eqnSKxBv'
        config.access_token        = '2846465294-QPuUihpQp5FjOPlKAYanUBgRXhe3EWAUJMqLw0q'
        config.access_token_secret = 'mjYo0LoUnbKT4XYhyNfgH4n0xlr2GCoxBZzYyTPfuPGwk'
      end

      if verified == true && (self.address == nil || self.address == "" || (self.address.downcase == self.name.downcase))
        radius =  1.0
      else
        radius = 0.075 #Venue.meters_to_miles(100)
      end

      query = ""
      top_tags = [self.tag_1, self.tag_2, self.tag_3, self.tag_4, self.tag_5].compact#self.meta_datas.order("relevance_score DESC LIMIT 5")
      if top_tags.count > 0
        top_tags.each{|tag| query+=(tag+" OR ")}        
        query+= self.name
      else
        query = self.name
      end

      last_tweet_id = Tweet.where("venue_id = ?", self.id).order("twitter_id desc").first.try(:twitter_id)
      #begin
        if last_tweet_id != nil
          new_venue_tweets = client.search(query+" -rt", result_type: "recent", geocode: "#{latitude},#{longitude},#{radius}km", since_id: "#{last_tweet_id}").take(20).collect.to_a rescue []
        else
          new_venue_tweets = client.search(query+" -rt", result_type: "recent", geocode: "#{latitude},#{longitude},#{radius}km").take(20).collect.to_a rescue []
        end
        self.update_columns(last_twitter_pull_time: Time.now)

        if new_venue_tweets.length > 0
          if delay_conversion == true
            Tweet.delay.bulk_conversion(new_venue_tweets, self, nil, nil, nil, nil)
          else
            Tweet.bulk_conversion(new_venue_tweets, self, nil, nil, nil, nil)
          end
          #new_venue_tweets.each{|tweet| Tweet.delay.create!(:twitter_id => tweet.id, :tweet_text => tweet.text, :image_url_1 => Tweet.implicit_image_url_1(tweet), :image_url_2 => Tweet.implicit_image_url_2(tweet), :image_url_3 => Tweet.implicit_image_url_3(tweet), :author_id => tweet.user.id, :handle => tweet.user.screen_name, :author_name => tweet.user.name, :author_avatar => tweet.user.profile_image_url.to_s, :timestamp => tweet.created_at, :from_cluster => false, :venue_id => self.id, :popularity_score => Tweet.popularity_score_calculation(tweet.user.followers_count, tweet.retweet_count, tweet.favorite_count))}
        end
        new_venue_tweets
      #rescue
      #  puts "TWEET ERROR OCCURRED"
      #  return nil
      #end
  end

  def self.surrounding_twitter_tweets(user_lat, user_long, venue_ids)
    surrounding_venue_ids = venue_ids.split(',').map(&:to_i) rescue []
    client = Twitter::REST::Client.new do |config|
      config.consumer_key        = '286I5Eu8LD64ApZyIZyftpXW2'
      config.consumer_secret     = '4bdQzIWp18JuHGcKJkTKSl4Oq440ETA636ox7f5oT0eqnSKxBv'
      config.access_token        = '2846465294-QPuUihpQp5FjOPlKAYanUBgRXhe3EWAUJMqLw0q'
      config.access_token_secret = 'mjYo0LoUnbKT4XYhyNfgH4n0xlr2GCoxBZzYyTPfuPGwk'
    end
    surrounding_tweets = []
    radius = 200 #Venue.meters_to_miles(200)
    
    if surrounding_venue_ids.count > 0
      location_query = ""
      tag_query = ""
      
      underlying_venues = Venue.where("id IN (?)", surrounding_venue_ids).order("popularity_rank DESC LIMIT 4").select("name")
      underlying_venues.each{|v| location_query+=(v.name+" OR ")}
      tags = MetaData.cluster_top_meta_tags(venue_ids)
      tags.each{|tag| tag_query+=(tag.first.last+" OR ") if tag.first.last != nil || tag.first.last != ""}
      
      location_query.chomp!(" OR ") 
      tag_query.chomp!(" OR ") 

      location_tweets = client.search(location_query+" -rt", result_type: "recent", geo_code: "#{user_lat},#{user_long},#{radius}mi").take(20).collect.to_a
      tag_query_tweets = client.search(tag_query+" -rt", result_type: "recent", geo_code: "#{user_lat},#{user_long},#{radius}mi").take(20).collect.to_a
      
      surrounding_tweets << location_tweets
      surrounding_tweets << tag_query_tweets
      surrounding_tweets.flatten!.compact!
    else
      query = user_lat.to_s + "," + user_long.to_s
      result = Geocoder.search(query).first 
      result_city = result.city || result.county
      result_city.slice!(" County")

      user_city = result_city
      user_state = result.state
      user_country = result.country

      vague_query = user_city+" OR "+user_state+" OR "+user_country
      surrounding_tweets = client.search(vague_query+" -rt", result_type: "recent", geo_code: "#{user_lat},#{user_long},#{radius}mi").take(20).collect.to_a
    end
    
    if surrounding_tweets.length > 0
      Tweet.delay.bulk_conversion(surrounding_tweets, nil, user_lat, user_long, 18, nil)
      #surrounding_tweets.each{|tweet| Tweet.delay.create!(:twitter_id => tweet.id, :tweet_text => tweet.text, :image_url_1 => Tweet.implicit_image_url_1(tweet), :image_url_2 => Tweet.implicit_image_url_2(tweet), :image_url_3 => Tweet.implicit_image_url_3(tweet), :author_id => tweet.user.id, :handle => tweet.user.screen_name, :author_name => tweet.user.name, :author_avatar => tweet.user.profile_image_url.to_s, :timestamp => tweet.created_at, :from_cluster => true, :latitude => user_lat, :longitude => user_long, :popularity_score => Tweet.popularity_score_calculation(tweet.user.followers_count, tweet.retweet_count, tweet.favorite_count))}
    end

    return surrounding_tweets.sort_by{|tweet| Tweet.popularity_score_calculation(tweet.user.followers_count, tweet.retweet_count, tweet.favorite_count)}  
  end

  def set_last_tweet_details(tweet)
    self.update_columns(lytit_tweet_id: tweet.id)
    self.update_columns(twitter_id: tweet.twitter_id)
    self.update_columns(tweet_text: tweet.tweet_text)
    self.update_columns(tweet_created_at: tweet.timestamp)
    self.update_columns(tweet_author_name: tweet.author_name)
    self.update_columns(tweet_author_id: tweet.author_id)
    self.update_columns(tweet_author_avatar_url: tweet.author_name)
    self.update_columns(tweet_handle: tweet.handle)
  end

=begin
  def self.surrounding_feed(lat, long, surrounding_venue_ids)
    if surrounding_venue_ids != nil and surrounding_venue_ids.length > 0
      meter_radius = 100
      surrounding_instagrams = (Instagram.media_search(lat, long, :distance => meter_radius, :count => 20, :min_timestamp => (Time.now-24.hours).to_time.to_i)).sort_by{|inst| Venue.spherecial_distance_between_points(lat, long, inst.location.latitude, inst.location.longitude)}
      surrounding_instagrams.map!(&:to_hash)

      if surrounding_instagrams.count >= 20
        surrounding_feed = surrounding_instagrams
      else
        inst_lytit_posts = []
        inst_lytit_posts << surrounding_instagrams
        inst_lytit_posts << VenueComment.joins(:venue).where("venues.id IN (#{surrounding_venue_ids})").order("rating DESC").order("name ASC").order("venue_comments.time_wrapper DESC")
        inst_lytit_posts.flatten!
        surrounding_feed = inst_lytit_posts
      end

    else
      meter_radius = 5000
      surrounding_instagrams = (Instagram.media_search(lat, long, :distance => meter_radius, :count => 100, :min_timestamp => (Time.now-24.hours).to_time.to_i)).sort_by{|inst| Geocoder::Calculations.distance_between([lat.to_f, long.to_f], [inst.location.latitude.to_f, inst.location.longitude.to_f], :units => :km)}
      
      surrounding_instagrams.map!(&:to_hash)
      surrounding_feed = surrounding_instagrams
    end


    #converting to lytit venue comments
    VenueComment.delay.convert_bulk_instagrams_to_vcs(surrounding_instagrams, nil)

    return surrounding_feed
  end
=end 

  def self.spherecial_distance_between_points(lat_1, long_1, lat_2, long_2)
    result = Geocoder::Calculations.distance_between([lat_1, long_1], [lat_2, long_2], :units => :km)
    if result >= 0.0
      result
    else
      1000.0
    end
  end

  #VI. LYT Algorithm Related Calculations and Calibrations ------------------------->
  def Venue.update_venue_ratings_in(target_sphere)
    for venue in Venue.where("l_sphere = ?", target_sphere).joins(:lyt_spheres)
      if venue.latest_rating_update_time != nil and venue.latest_rating_update_time < Time.now - 10.minutes
        venue.update_rating()
      end
      
      if venue.is_visible? == true #venue.rating != nil && venue.rating > 0.0 
        venue.update_popularity_rank
      else
        venue.update_columns(popularity_rank: 0.0)
        LytSphere.where("venue_id = ?", venue.id).delete_all
      end
    end
  end

  def Venue.recalibrate_all_venues
    Venue.update_all(rating: nil)
    Venue.update_all(color_rating: -1.0)
    Venue.update_all(r_up_votes: 1.0)
    clean_history = {:hour_1=>{:rating=> 0, :count => 0}, 
    :hour_2=>{:rating=> 0, :count => 0}, :hour_3=>{:rating=> 0, :count => 0}, :hour_4=>{:rating=> 0, :count => 0},
    :hour_5=>{:rating=> 0, :count => 0}, :hour_6=>{:rating=> 0, :count => 0},
    :hour_7=>{:rating=> 0, :count => 0}, :hour_8=>{:rating=> 0, :count => 0}, :hour_9=>{:rating=> 0, :count => 0},
    :hour_10=>{:rating=> 0, :count => 0}, :hour_11=>{:rating=> 0, :count => 0}, :hour_12=>{:rating=> 0, :count => 0},
    :hour_13=>{:rating=> 0, :count => 0}, :hour_14=>{:rating=> 0, :count => 0}, :hour_15=>{:rating=> 0, :count => 0},
    :hour_16=>{:rating=> 0, :count => 0}, :hour_17=>{:rating=> 0, :count => 0}, :hour_18=>{:rating=> 0, :count => 0},
    :hour_19=>{:rating=> 0, :count => 0}, :hour_20=>{:rating=> 0, :count => 0}, :hour_21=>{:rating=> 0, :count => 0},
    :hour_22=>{:rating=> 0, :count => 0}, :hour_23=>{:rating=> 0, :count => 0}, :hour_0=>{:rating=> 0, :count => 0}}
    Venue.update_all(hist_rating_avgs: clean_history)
    Venue.update_all(popularity_rank: 0.0)
  end

  def Venue.update_all_active_venue_ratings
    for venue in Venue.where("rating IS NOT NULL")
      if venue.is_visible? == true
        if venue.latest_rating_update_time != nil and venue.latest_rating_update_time < Time.now - 5.minutes
          venue.update_rating()
        end
      end
    end
  end

  def v_up_votes
    LytitVote.where("venue_id = ? AND value = ? AND created_at >= ?", self.id, 1, Time.now.beginning_of_day)
  end

  def v_down_votes
    LytitVote.where("venue_id = ? AND value = ? AND created_at >= ?", self.id, -1, valid_votes_timestamp)
  end

  def bayesian_voting_average
    up_votes_count = self.v_up_votes.size
    down_votes_count = self.v_down_votes.size

    (LytitConstants.bayesian_average_c * LytitConstants.bayesian_average_m + (up_votes_count - down_votes_count)) /
    (LytitConstants.bayesian_average_m + (up_votes_count + down_votes_count))
  end

  def account_new_vote(vote_value, vote_id)
    #puts "bar position = #{LytitBar.instance.position}"
    if vote_value > 0
      puts "up vote, accounting"
      account_up_vote
    else
      puts "down vote, accounting"
      account_down_vote
    end

    recalculate_rating(vote_id)
  end

  def recalculate_rating(vote_id)
    y = (1.0 / (1 + LytitConstants.rating_loss_l)).round(4)

    a = self.r_up_votes || (1.0 + get_k)
    b = self.r_down_votes || 1.0

    puts "A = #{a}, B = #{b}, Y = #{y}"

    #x = LytitBar::inv_inc_beta(a, b, y)
    # for some reason the python interpreter installed is not recognized by RubyPython
    x = `python2 -c "import scipy.special;print scipy.special.betaincinv(#{a}, #{b}, #{y})"`

    if $?.to_i == 0
      puts "rating before = #{self.rating}"
      puts "rating after = #{x}"

      new_rating = eval(x).round(4)

      self.rating = new_rating

      vote = LytitVote.find(vote_id)
      vote.update_columns(rating_after: new_rating)
      save
    else
      puts "Could not calculate rating. Status: #{$?.to_i}"
    end
  end

  def update_r_up_votes(time_wrapped_posting_time)
    if time_wrapped_posting_time != nil && latest_posted_comment_time != nil
      new_r_up_vote_count = ((self.r_up_votes-1.0) * 2**((-(time_wrapped_posting_time.to_datetime - latest_posted_comment_time.to_datetime)/60.0) / (LytitConstants.vote_half_life_h))+2.0).round(4)
    else
      new_r_up_vote_count = self.r_up_votes + 1.0
    end
    
    self.update_columns(r_up_votes: new_r_up_vote_count)
  end

  def update_rating(after_post=false)
    latest_posted_comment_time = latest_posted_comment_time || Time.now
    old_r_up_vote_count = self.r_up_votes 
    p "Old R Up Votes: #{old_r_up_vote_count}"
    if after_post == true
      new_r_up_vote_count = ((old_r_up_vote_count) * 2**((-(Time.now.utc - latest_posted_comment_time.to_datetime)/60.0) / (LytitConstants.vote_half_life_h))).round(4)+1.0
    else
      puts "no vote accounted"
      new_r_up_vote_count = ((old_r_up_vote_count) * 2**((-(Time.now.utc - latest_posted_comment_time.to_datetime)/60.0) / (LytitConstants.vote_half_life_h))).round(4)
    end
    p "New R Up Votes: #{new_r_up_vote_count}"
    self.update_columns(r_up_votes: new_r_up_vote_count)
    p "R up vote after update #{self.r_up_votes}"

    y = (1.0 / (1 + LytitConstants.rating_loss_l)).round(4)

    a = new_r_up_vote_count >= 1.0 ? r_up_votes : 1.0
    b = 1.0

    puts "A = #{a}, B = #{b}, Y = #{y}"

    # x = LytitBar::inv_inc_beta(a, b, y)
    # for some reason the python interpreter installed is not recognized by RubyPython
    x = `python2 -c "import scipy.special;print scipy.special.betaincinv(#{a}, #{b}, #{y})"`

    if $?.to_i == 0
      puts "rating before = #{self.rating}"
      puts "rating after = #{x}"

      new_rating = eval(x).round(4)
      color_rating = new_rating.round_down(1)

      update_columns(rating: new_rating)
      update_columns(color_rating: color_rating)
      update_historical_avg_rating
      update_popularity_rank

      update_columns(latest_rating_update_time: Time.now)
    else
      puts "Could not calculate rating. Status: #{$?.to_i}"
    end
  end

  def update_historical_avg_rating
    tz_offset = time_zone_offset || 0.0
    current_hour = (Time.now.utc + tz_offset.hours).hour.to_i
    ratings_hash = self.hist_rating_avgs
    key = "hour_#{current_hour}"
    count = ratings_hash[key]["count"]
    previous_hist_rating = ratings_hash[key]["rating"]    
    current_rating = rating || 0
    updated_hist_rating = (previous_hist_rating * count.to_f + current_rating) / (count.to_f + 1.0)
    ratings_hash[key]["count"] = count + 1
    ratings_hash[key]["rating"] = updated_hist_rating
    self.update_columns(hist_rating_avgs: ratings_hash)
  end

  def update_popularity_rank
    view_half_life = 60.0 #minutes
    latest_page_view_time_wrapper = latest_page_view_time || Time.now
    new_page_view_count = (self.page_views * 2 ** ((-(Time.now - latest_page_view_time_wrapper)/60.0) / (view_half_life))).round(4)
    self.update_columns(page_views: new_page_view_count)
    tz_offset = self.time_zone_offset || 0.0
    current_hour = (Time.now.utc + tz_offset.hours).hour.to_i
    key = "hour_#{current_hour}"
    historical_rating = self.hist_rating_avgs[key]["rating"]
    current_rating = rating || 0
    k = 1.0
    m = 0.01
    e = 0.2
    new_popularity_rank = (current_rating + (current_rating - historical_rating)*k) + new_page_view_count*m + event_happening?*e
    self.update_columns(popularity_rank: new_popularity_rank)
  end

  def is_visible?
    visible = true
    if (self.rating == nil or self.rating.round(1) == 0.0) || (Time.now - latest_posted_comment_time)/60.0 >= (LytitConstants.threshold_to_venue_be_shown_on_map)
      visible = false
    end

=begin
    if city == "New York" && (Time.now - latest_posted_comment_time)/60.0 >= (LytitConstants.threshold_to_venue_be_shown_on_map)
      visible = false
    else
      if city != "New York" && (Time.now - latest_posted_comment_time)/60.0 >= LytitConstants.threshold_to_venue_be_shown_on_map
        visible = false
      end
    end
=end

    if visible == false
      self.update_columns(rating: nil)
      self.update_columns(r_up_votes: 1.0)
      self.update_columns(r_down_votes: 1.0)
      self.update_columns(color_rating: -1.0)
      self.update_columns(popularity_rank: 0.0)
      #self.lyt_spheres.delete_all
    end

    return visible
  end

  def reset_r_vector
    self.r_up_votes = 1 + get_k
    self.r_down_votes = 1
    save
  end

  #priming factor that used to be calculted from historical average rating of a place
  def get_k
    0
  end  

  def set_top_tags
    top_tags = self.meta_datas.order("relevance_score DESC").limit(5)
    self.update_columns(tag_1: top_tags[0].try(:meta))
    self.update_columns(tag_2: top_tags[1].try(:meta))
    self.update_columns(tag_3: top_tags[2].try(:meta))
    self.update_columns(tag_4: top_tags[3].try(:meta))
    self.update_columns(tag_5: top_tags[4].try(:meta))
  end

  def Venue.cleanup_and_calibration
    active_venue_ids = "SELECT venue_id FROM lyt_spheres"
    stale_venue_ids = "SELECT id FROM venues WHERE id NOT IN (#{active_venue_ids}) AND color_rating > -1.0"
    Venue.where("id IN (#{stale_venue_ids})").update_all(rating: nil)
    Venue.where("id IN (#{stale_venue_ids})").update_all(color_rating: -1.0)
    Venue.where("id IN (#{stale_venue_ids})").update_all(popularity_rank: 0.0)

  end

  def Venue.cleanup_venues_for_crackle    
    feed_venue_ids = "SELECT venue_id FROM feed_venues"
    Venue.joins(:feed_venues).where("verified IS FALSE").update_all(verified: true)
    Venue.where("address IS NOT NULL AND verified IS FALSE").update_all(verified: true)
    false_venues = Venue.where("verified IS FALSE").pluck(:id)
    VenueComment.where("venue_id IN (?)", false_venues).delete_all
    MetaData.where("venue_id IN (?)", false_venues).delete_all
    LytitVote.where("venue_id IN (?)", false_venues).delete_all
    Tweet.where("venue_id IN (?)", false_venues).delete_all
    LytSphere.where("venue_id IN (?)", false_venues).delete_all
    VenuePageView.where("venue_id IN (?)", false_venues).delete_all
    Activity.where("venue_id IN (?)", false_venues).delete_all
  end

  def Venue.timezone_and_vortex_calibration
    ivs = InstagramVortex.all
    for iv in ivs
      iv.set_timezone_offsets
      center_point = [iv.latitude, iv.longitude]
      proximity_box = Geokit::Bounds.from_point_and_radius(center_point, 10, :units => :kms)
      nearby_venues = Venue.in_bounds(proximity_box)
      nearby_venues.update_all(instagram_vortex_id: iv.id)
      nearby_venues.update_all(time_zone: iv.time_zone)
      nearby_venues.update_all(time_zone_offset: iv.time_zone_offset)
    end
  end

  def increment_rating(vc_created_at)
    #vote = LytitVote.create!(:value => 1, :venue_id => self.id, :user_id => nil, :venue_rating => self.rating ? self.rating : 0, 
    #            :prime => 0.0, :raw_value => 1.0, :time_wrapper => vc_created_at)
    #self.update_r_up_votes(vc_created_at)
    if latest_rating_update_time != nil and latest_rating_update_time < Time.now - 10.minutes
      self.update_rating()
      self.update_columns(latest_rating_update_time: Time.now)
    end
  end

  def event_happening?
    self.events.where("start_time >= ? AND end_time <= ?", Time.now, Time.now).any? ? 1:0
  end

  #----------------------------------------------------------------------------->
  #VII.

  private 

  def valid_votes_timestamp
    now = Time.now
    now.hour >= 6 ? now.at_beginning_of_day + 6.hours : now.yesterday.at_beginning_of_day + 6.hours
  end

  def self.with_color_ratings(venues)
    ret = []

    diff_ratings = Set.new
    for venue in venues
      if venue.rating
        rat = venue.rating.round(2)
        diff_ratings.add(rat)
      end
    end

    diff_ratings = diff_ratings.to_a.sort

    step = 1.0 / (diff_ratings.size - 1)

    colors_map = {0.0 => 0.0} # null ratings will be out of the distribution range, just zero
    color = -step
    for rating in diff_ratings
      color += step
      colors_map[rating] = color.round(2)
    end

    for venue in venues
      rating = venue.rating ? venue.rating.round(2) : 0.0
      ret.append(venue.as_json.merge({'color_rating' => venue.is_visible? ? colors_map[rating] : -1}))
    end

    ret
  end

  def validate_menu_link
    if menu_link.present?
      begin
        uri = URI.parse(menu_link)
        raise URI::InvalidURIError unless uri.kind_of?(URI::HTTP)
        response = Net::HTTP.get_response(uri)
      rescue URI::InvalidURIError
        errors.add(:menu_link, "is not a valid URL.")
      rescue
        errors.add(:menu_link, "is not reachable. Please check the URL and try again.")
      end
    end
  end

  def minutes_since_last_vote
    last_vote = LytitVote.where("venue_id = ?", self.id).last

    if last_vote
      last = last_vote.created_at
      now = Time.now.utc

      (now - last) / 1.minute
    else
      LytitConstants.threshold_to_venue_be_shown_on_map
    end
  end

  def account_up_vote
    up_votes = self.v_up_votes.order('id ASC').to_a
    last = up_votes.pop # current vote should not be considered for the sum of the past

    # we sum 2 instead of 1 because the initial value of the R-vector is (1 + K, 1)
    # refer to the algo spec document
    update_columns(r_up_votes: (get_sum_of_past_votes(up_votes, last.try(:time_wrapper), false) + 2.0 + get_k).round(4))

    #making sure down votes component is initialized (is set by default though to 1.0)
    if self.r_down_votes < 1.0
      update_columns(r_down_votes: 1.0)
    end
  end

  def account_down_vote
    down_votes = self.v_down_votes.order('id ASC').to_a
    last = down_votes.pop # current vote should not be considered for the sum of the past

    # we sum 2 instead of 1 because the initial value of the R-vector is (1 + K, 1)
    # refer to the algo spec document
    update_columns(r_down_votes: (get_sum_of_past_votes(down_votes, last.try(:time_wrapper), true) + 2.0).round(4))

    #if first vote is a down vote up votes must be primed
    if self.r_up_votes <= 1.0 && get_k > 0
      update_columns(r_up_votes: (1.0 + get_k))
    end
  end

  # we need the timestamp of the last vote, since the accounting of votes
  # is executed in parallel (new thread) and probably NOT right after the
  # push of the current vote through the API
  #
  # Time.now could be used if we have guaranteed that the accounting of
  # the vote will be done right away, which is not the case with the use of
  # delayed jobs
  def get_sum_of_past_votes(votes, timestamp_last_vote, is_down_vote)
    if not timestamp_last_vote
      timestamp_last_vote = Time.now.utc
    end

    old_votes_sum = 0
    for vote in votes
      minutes_passed_since_vote = (timestamp_last_vote - vote.time_wrapper) / 1.minute

      if is_down_vote
        old_votes_sum += 2 ** ((- minutes_passed_since_vote) / (2 * LytitConstants.vote_half_life_h))
      else
        old_votes_sum += 2 ** ((- minutes_passed_since_vote) / LytitConstants.vote_half_life_h)
      end
    end

    old_votes_sum
  end

  def Venue.linked_user_lists(v_id, u_id)
    user_list_ids = "SELECT feed_id FROM feed_users WHERE user_id = #{u_id}"
    linked_feed_ids = "SELECT feed_id FROM feed_venues WHERE venue_id = #{v_id} AND feed_id IN (#{user_list_ids})"
    Feed.where("id IN (#{linked_feed_ids})") 
  end

end
