class Group < ActiveRecord::Base
  acts_as_paranoid
#Checks if the Group name is not too long or already taken
  validates_length_of :name, :within => 1..30
  validates_uniqueness_of :name, :message => "Name already exists"

  validates :name, presence: true
  validates_uniqueness_of :name, case_sensitive: false

  validates_inclusion_of :is_public, in: [true, false]
  validates :password, presence: true, :if => :should_validate_password?

  validates_inclusion_of :can_link_events, in: [true, false]
  
  validates_inclusion_of :can_link_venues, in: [true, false]

  has_many :groups_users
  has_many :users, through: :groups_users

  has_many :groups_venues
  has_many :venues, through: :groups_venues

  has_many :events_groups
  has_many :events, through: :events_groups

  def should_validate_password?
  	not is_public
  end
  
  # def can_link_event?
  #   can_link_event
  #end

  def join(user_id, pwd)
    if !self.is_public? and self.password != pwd
      return false, 'Verification password failed'
    end

    if !self.is_user_member?(user_id)
      # do nothing if user is already a member
      GroupsUser.create(group_id: self.id, user_id: user_id)
    end
    true
  end

  def remove(user_id)
    GroupsUser.where("group_id = ? and user_id = ?", self.id, user_id).destroy_all
  end

  def is_user_admin?(user_id)
    GroupsUser.where("group_id = ? and user_id = ?", self.id, user_id).first.try(:is_admin) ? true : false
  end

  def is_user_member?(user_id)
    GroupsUser.where("group_id = ? and user_id = ?", self.id, user_id).first ? true : false
  end

  def return_password_if_admin(user_id)
    self.is_user_admin?(user_id) ? self.password : nil
  end

  def toggle_user_admin(user_id, approval)
    group_user = GroupsUser.where("group_id = ? and user_id = ?", self.id, user_id).first
    group_user.update(:is_admin => (approval == 'yes' ? true : false))
  end

  def add_venue(venue_id, user_id)
    if self.is_user_member?(user_id)
      GroupsVenue.create(group_id: self.id, venue_id: venue_id, user_id: user_id)
      return true
    else
      return false, 'You are not member of this group'
    end
  end

  def remove_venue(venue_id, user_id)
    GroupsVenue.where("group_id = ? and venue_id = ?", self.id, venue_id).destroy_all
    return true
  end

  def venues_with_user_who_added
    venues = self.venues.order("venues.name ASC").as_json
    for venue in venues
      gv = GroupsVenue.where("group_id = ? and venue_id = ?", self.id, venue["id"]).first
      info = gv.as_json.slice("created_at", "user_id")
      user = User.find(info["user_id"])
      venue.update({"venue_added_at" => info["created_at"], "user_adding_venue" => user.name})
    end
    venues
  end

  def send_notification_to_users(user_ids, event_id)
    for user_id in user_ids
      user = User.find(user_id)

      payload = {
        :object_id => event_id, 
        :type => 'event_added', 
        :user_id => user_id
      }

      if user.push_token
        APNS.delay.send_notification(user.push_token, {:alert => '', :content_available => 1, :other => payload})
      end

      if user.gcm_token
        options = {
          :data => payload
        }
        request = HiGCM::Sender.new(ENV['GCM_API_KEY'])
        request.send([user.gcm_token], options)
      end
      
    end
  end

end
