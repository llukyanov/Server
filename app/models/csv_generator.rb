class CsvGenerator

  def self.by_vote
    votes = LytitVote.where('created_at >= ?', Time.now.at_beginning_of_day + 6.hours)

    by_vote = CSV.open("public/voting_report_by_vote.csv", "wb") do |csv|
      data = ["ID", "Vote Type (up or down)", "Venue at which vote was placed", "Time at which vote was placed", 
      	      "LYTiT Rating at Venue at time of placed vote", "Priming Value of Venue where vote was placed"]

      csv << data

      votes.each do |v|
      	data = [v.id, v.value > 0 ? "up" : "down", v.venue_id, v.created_at, v.venue_rating, v.prime]

      	csv << data
      end
    end
  end

  def self.by_venue
    venues = Venue.all.order(:id)

    by_venue = CSV.open("public/voting_report_by_venue.csv", "wb") do |csv|
      data = ["ID", "LYTiT Rating", "Number of up votes", "Number of down votes", "Time Since Last Placed Up Vote (minutes)",
              "Time Since Last Placed Down Vote (minutes)", "Venue Primer Value", "Venue Google Places Rating",
              "Average Interval between placed Up Votes (minutes)", "Average Interval between placed Down Votes (minutes)"]

      csv << data

      venues.each do |v|
        venue_id = v.id

        time_since_last_up = minutes_since_last_vote(venue_id, 1)
	    time_since_last_down = minutes_since_last_vote(venue_id, -1)

	    up_votes = LytitVote.where('venue_id = ? AND value = ? AND created_at >= ?', venue_id, 1, Time.now.at_beginning_of_day + 6.hours)
	    down_votes = LytitVote.where('venue_id = ? AND value = ? AND created_at >= ?', venue_id, -1, Time.now.at_beginning_of_day + 6.hours)

	    average_up = average_time_between(up_votes)
	    average_down = average_time_between(down_votes)

	    data = [v.id, v.rating, up_votes.size, down_votes.size, time_since_last_up, time_since_last_down, v.get_k, 
	            v.google_place_rating, average_up, average_down]

	    csv << data
      end
    end
  end

  private

  def self.average_time_between(votes)
    count = votes.size

    if count > 0
      if count == 1
        return minutes_since_last_vote(votes.first.venue_id, votes.first.value)
      end

      sum = 0
      for i in (0...count-1)
        diff = (votes[i+1].created_at - votes[i].created_at) / 1.minute
        sum += diff
      end

      (sum / count).round(2)
    else
      -1 # there are no votes
    end
  end

  def self.minutes_since_last_vote(venue_id, vote)
    last_vote = LytitVote.where("venue_id = ? AND value = ? AND created_at >= ?", venue_id, vote, Time.now.at_beginning_of_day + 6.hours).last

    if last_vote
      last = last_vote.created_at
      now = Time.now

      ((now - last) / 1.minute).round(2)
    else
      -1 # there are no votes
    end
  end

end
