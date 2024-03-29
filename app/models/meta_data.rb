class MetaData < ActiveRecord::Base
	belongs_to :venue
	belongs_to :venue_comment

	def self.increment_relevance_score(data, v_id)
		md = MetaData.where("meta = ? AND venud_id = ?", data, v_id).first
		relevance_half_life = 360.0

		begin
			old_score = md.relevance_score
			new_score = old_score * 2 ** ((-(Time.now - md.updated_at)/60.0) / (relevance_half_life)).round(4)+1.0
			md.update_columns(relevance_score: new_score)
		rescue
			puts "Could not locate MetaData object"
		end
	end

	def update_and_return_relevance_score
		relevance_half_life = 360.0
		old_score = self.relevance_score
		new_score = old_score * 2 ** ((-(Time.now - self.updated_at)/60.0) / (relevance_half_life)).round(4)+1.0
		self.update_columns(relevance_score: new_score)
		return self.relevance_score
	end
end