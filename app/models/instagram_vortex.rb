class InstagramVortex < ActiveRecord::Base
	has_many :vortex_paths, :dependent => :destroy

	def move
		#(109.0 * 1000) meters ~= 1 degree latitude
		path = self.vortex_path

		if self.movement_direction == nil
			#begin moving the vortex south 
			update_columns(movement_direction: 270)
			
			new_lat = latitude - path.increment_distance / (109.0 * 1000)
			update_columns(latitude: new_lat)
		else
			#must check if we reached the center of the vortex_path. If so we move vortex back to the path origin. (the 1.3 is an over-rounded down sqrt(2))
			path_center_lat = path.origin_lat - (path.span/2) / (109.0 * 1000)
			path_center_long = path.origin_long + (path.span/2) / (113.2 * 1000 * Math.cos(path.origin_lat * Math::PI / 180))
			
			if Geocoder::Calculations.distance_between([latitude, longitude], [path_center_lat, path_center_long])*1609.34 < 1.3*path.increment_distance
				update_columns(latitude: path.origin_lat)
				update_columns(longitude: path.origin_long)
			else
				if self.movement_direction == 270
					new_lat = latitude - path.increment_distance / (109.0 * 1000)
					if new_lat >= path.origin_lat - span / (109.0 * 1000)
						#keep moving vortex south
						update_columns(latitude: new_lat)
					else
						#move vortex east because reached path bound
						new_long = longitude + path.increment_distance / (113.2 * 1000 * Math.cos(latitude * Math::PI / 180))
						update_columns(longitude: new_long)
						update_columns(movement_direction: 360)
					end
				
				elsif self.movement_direction == 360
					new_long = longitude + path.increment_distance / (113.2 * 1000 * Math.cos(latitude * Math::PI / 180))
					if new_long <= path.origin_long + path.span / (113.2 * 1000 * Math.cos(latitude * Math::PI / 180))
						#keep moving vortex east
						update_columns(longitude: new_long)
					else
						#move vortex north because reached path bound
						new_lat = latitude + path.increment_distance / (109.0 * 1000)
						update_columns(latitude: new_lat)
						update_columns(movement_direction: 90)
					end
				elsif self.movement_direction == 90
					new_lat = latitude + path.increment_distance / (109.0 * 1000)
					if new_lat <= path.origin_lat
						#keep moving vortex north
						update_columns(latitude: new_lat)
					else
						#move vortex west because reached path bound
						new_long = longitude - path.increment_distance / (113.2 * 1000 * Math.cos(latitude * Math::PI / 180))
						update_columns(longitude: new_long)
						update_columns(movement_direction: 180)
					end
				else #180
					new_long = longitude - path.increment_distance / (113.2 * 1000 * Math.cos(latitude * Math::PI / 180)) 
					if new_long >= path.origin_long
						#keep moving vortex west
						update_columns(longitude: new_long)
					else
						#move vortex south because reached path bound
						new_lat = latitude - path.increment_distance / (109.0 * 1000)
						update_columns(latitude: new_lat)
						update_columns(movement_direction: 270)
					end
				
				end
			end
		end

	end

end