# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150613030906) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "pg_stat_statements"

  create_table "announcement_users", force: true do |t|
    t.integer  "user_id"
    t.integer  "announcement_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "announcement_users", ["announcement_id"], name: "index_announcement_users_on_announcement_id", using: :btree
  add_index "announcement_users", ["user_id"], name: "index_announcement_users_on_user_id", using: :btree

  create_table "announcements", force: true do |t|
    t.string   "news"
    t.boolean  "send_to_all", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title"
  end

  create_table "bounties", force: true do |t|
    t.float    "lumen_reward"
    t.integer  "user_id"
    t.integer  "venue_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "validity",                     default: true
    t.string   "media_type"
    t.string   "detail"
    t.boolean  "response_received",            default: false
    t.datetime "expiration"
    t.datetime "last_viewed_claim_time"
    t.integer  "venue_comment_id"
    t.integer  "num_responses",                default: 0
    t.boolean  "decrement_venue_bounty_count", default: true
    t.string   "latest_response_1"
    t.string   "latest_response_2"
    t.string   "latest_response_3"
    t.string   "latest_response_4"
    t.string   "latest_response_5"
    t.string   "latest_response_6"
    t.string   "latest_response_7"
    t.string   "latest_response_8"
    t.string   "latest_response_9"
    t.string   "latest_response_10"
  end

  add_index "bounties", ["user_id"], name: "index_bounties_on_user_id", using: :btree
  add_index "bounties", ["venue_id"], name: "index_bounties_on_venue_id", using: :btree

  create_table "bounty_claim_rejection_trackers", force: true do |t|
    t.integer  "user_id"
    t.integer  "venue_comment_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "active",           default: true
  end

  add_index "bounty_claim_rejection_trackers", ["user_id"], name: "index_bounty_claim_rejection_trackers_on_user_id", using: :btree
  add_index "bounty_claim_rejection_trackers", ["venue_comment_id"], name: "index_bounty_claim_rejection_trackers_on_venue_comment_id", using: :btree

  create_table "bounty_pricing_constants", force: true do |t|
    t.string   "constant_name"
    t.float    "constant_value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "bounty_subscribers", force: true do |t|
    t.integer  "bounty_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "bounty_subscribers", ["bounty_id"], name: "index_bounty_subscribers_on_bounty_id", using: :btree
  add_index "bounty_subscribers", ["user_id"], name: "index_bounty_subscribers_on_user_id", using: :btree

  create_table "comment_views", force: true do |t|
    t.integer  "venue_comment_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "comment_views", ["user_id"], name: "index_comment_views_on_user_id", using: :btree
  add_index "comment_views", ["venue_comment_id", "user_id"], name: "index_comment_views_on_venue_comment_id_and_user_id", unique: true, using: :btree
  add_index "comment_views", ["venue_comment_id"], name: "index_comment_views_on_venue_comment_id", using: :btree

  create_table "coupon_claimers", force: true do |t|
    t.integer  "coupon_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "coupon_claimers", ["coupon_id"], name: "index_coupon_claimers_on_coupon_id", using: :btree

  create_table "coupons", force: true do |t|
    t.string   "code"
    t.float    "lumen_gift"
    t.integer  "supply"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "delayed_jobs", force: true do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "exported_data_csvs", force: true do |t|
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "csv_file_file_name"
    t.string   "csv_file_content_type"
    t.integer  "csv_file_file_size"
    t.datetime "csv_file_updated_at"
    t.string   "type"
    t.integer  "job_id"
  end

  create_table "flagged_comments", force: true do |t|
    t.integer  "venue_comment_id"
    t.integer  "user_id"
    t.text     "message"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "instagram_location_id_trackers", force: true do |t|
    t.integer "venue_id"
    t.string  "primary_instagram_location_id"
    t.string  "secondary_instagram_location_id"
    t.integer "primary_instagram_location_id_pings",        default: 0
    t.integer "secondary_instagram_location_id_pings",      default: 0
    t.integer "tertiary_instagram_location_id_pings",       default: 0
    t.string  "tertiary_instagram_location_id"
    t.integer "primary_instagram_location_id_miss_count",   default: 0
    t.integer "secondary_instagram_location_id_miss_count", default: 0
    t.integer "tertiary_instagram_location_id_miss_count",  default: 0
  end

  add_index "instagram_location_id_trackers", ["venue_id"], name: "index_instagram_location_id_trackers_on_venue_id", using: :btree

  create_table "instagram_vortexes", force: true do |t|
    t.float    "latitude"
    t.float    "longitude"
    t.datetime "last_instagram_pull_time"
    t.string   "city"
    t.float    "pull_radius"
    t.boolean  "active"
    t.string   "description"
    t.integer  "city_que"
  end

  create_table "lumen_constants", force: true do |t|
    t.string   "constant_name"
    t.float    "constant_value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "lumen_game_winners", force: true do |t|
    t.integer  "user_id"
    t.integer  "winning_validation_code"
    t.string   "paypal_info"
    t.boolean  "payment_made"
    t.boolean  "email_sent"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "lumen_game_winners", ["user_id"], name: "index_lumen_game_winners_on_user_id", using: :btree

  create_table "lumen_values", force: true do |t|
    t.float    "value"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "lytit_vote_id"
    t.integer  "venue_comment_id"
    t.string   "media_type"
    t.integer  "bounty_id"
  end

  add_index "lumen_values", ["user_id"], name: "index_lumen_values_on_user_id", using: :btree

  create_table "lyt_spheres", force: true do |t|
    t.integer  "venue_id"
    t.string   "sphere"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "lyt_spheres", ["sphere"], name: "index_lyt_spheres_on_sphere", using: :btree

  create_table "lytit_bars", force: true do |t|
    t.float "position"
  end

  create_table "lytit_constants", force: true do |t|
    t.string   "constant_name"
    t.float    "constant_value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "lytit_votes", force: true do |t|
    t.integer  "value"
    t.integer  "venue_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "venue_rating"
    t.float    "prime"
    t.float    "raw_value"
    t.float    "rating_after"
    t.datetime "time_wrapper"
  end

  add_index "lytit_votes", ["user_id"], name: "index_lytit_votes_on_user_id", using: :btree
  add_index "lytit_votes", ["venue_id"], name: "index_lytit_votes_on_venue_id", using: :btree

  create_table "menu_section_items", force: true do |t|
    t.string   "name"
    t.float    "price"
    t.integer  "menu_section_id"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  add_index "menu_section_items", ["menu_section_id"], name: "index_menu_section_items_on_menu_section_id", using: :btree

  create_table "menu_sections", force: true do |t|
    t.string   "name"
    t.integer  "venue_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  add_index "menu_sections", ["venue_id"], name: "index_menu_sections_on_venue_id", using: :btree

  create_table "meta_data", force: true do |t|
    t.string   "meta"
    t.integer  "venue_id"
    t.integer  "venue_comment_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "meta_data", ["meta"], name: "index_meta_data_on_meta", using: :btree

  create_table "roles", force: true do |t|
    t.string "name"
  end

  create_table "temp_posting_housings", force: true do |t|
    t.string   "comment"
    t.string   "media_type"
    t.string   "media_url"
    t.integer  "session"
    t.boolean  "username_private"
    t.integer  "user_id"
    t.integer  "venue_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "temp_posting_housings", ["user_id"], name: "index_temp_posting_housings_on_user_id", using: :btree
  add_index "temp_posting_housings", ["venue_id"], name: "index_temp_posting_housings_on_venue_id", using: :btree

  create_table "users", force: true do |t|
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.string   "email",                                                null: false
    t.string   "encrypted_password",     limit: 128,                   null: false
    t.string   "confirmation_token",     limit: 128
    t.string   "remember_token",         limit: 128,                   null: false
    t.string   "name"
    t.string   "authentication_token"
    t.text     "push_token"
    t.integer  "role_id"
    t.boolean  "username_private",                   default: false
    t.string   "gcm_token"
    t.float    "lumens",                             default: 0.0
    t.float    "lumen_percentile"
    t.float    "video_lumens",                       default: 0.0
    t.float    "image_lumens",                       default: 0.0
    t.float    "text_lumens",                        default: 0.0
    t.float    "bonus_lumens",                       default: 0.0
    t.integer  "total_views",                        default: 0
    t.float    "lumen_notification",                 default: 0.0
    t.string   "version",                            default: "1.0.0"
    t.float    "bounty_lumens",                      default: 0.0
    t.boolean  "can_claim_bounty",                   default: true
    t.datetime "latest_rejection_time"
    t.float    "adjusted_view_discount"
    t.boolean  "email_confirmed",                    default: false
    t.boolean  "registered",                         default: false
    t.string   "vendor_id"
    t.float    "monthly_gross_lumens",               default: 0.0
  end

  add_index "users", ["bonus_lumens"], name: "index_users_on_bonus_lumens", using: :btree
  add_index "users", ["email"], name: "index_users_on_email", using: :btree
  add_index "users", ["image_lumens"], name: "index_users_on_image_lumens", using: :btree
  add_index "users", ["lumens"], name: "index_users_on_lumens", using: :btree
  add_index "users", ["remember_token"], name: "index_users_on_remember_token", using: :btree
  add_index "users", ["role_id"], name: "index_users_on_role_id", using: :btree
  add_index "users", ["text_lumens"], name: "index_users_on_text_lumens", using: :btree
  add_index "users", ["video_lumens"], name: "index_users_on_video_lumens", using: :btree

  create_table "vendor_id_trackers", force: true do |t|
    t.string "used_vendor_id"
  end

  create_table "venue_comments", force: true do |t|
    t.string   "comment"
    t.string   "media_type"
    t.string   "media_url"
    t.integer  "user_id"
    t.integer  "venue_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "username_private",     default: false
    t.integer  "consider",             default: 2
    t.integer  "views",                default: 0
    t.float    "adj_views",            default: 0.0
    t.boolean  "from_user",            default: false
    t.integer  "session"
    t.string   "offset_created_at"
    t.integer  "bounty_id"
    t.boolean  "is_response"
    t.boolean  "is_response_accepted"
    t.string   "rejection_reason"
    t.string   "content_origin"
    t.datetime "time_wrapper"
    t.string   "instagram_id"
  end

  add_index "venue_comments", ["bounty_id"], name: "index_venue_comments_on_bounty_id", using: :btree
  add_index "venue_comments", ["instagram_id"], name: "index_venue_comments_on_instagram_id", unique: true, using: :btree
  add_index "venue_comments", ["user_id"], name: "index_venue_comments_on_user_id", using: :btree
  add_index "venue_comments", ["venue_id"], name: "index_venue_comments_on_venue_id", using: :btree

  create_table "venue_messages", force: true do |t|
    t.string   "message"
    t.integer  "venue_id"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "venue_messages", ["venue_id"], name: "index_venue_messages_on_venue_id", using: :btree

  create_table "venue_page_views", force: true do |t|
    t.integer  "user_id"
    t.integer  "venue_id"
    t.string   "venue_lyt_sphere"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "consider",         default: true
  end

  add_index "venue_page_views", ["user_id"], name: "index_venue_page_views_on_user_id", using: :btree
  add_index "venue_page_views", ["venue_id"], name: "index_venue_page_views_on_venue_id", using: :btree
  add_index "venue_page_views", ["venue_lyt_sphere"], name: "index_venue_page_views_on_venue_lyt_sphere", using: :btree

  create_table "venue_ratings", force: true do |t|
    t.integer  "user_id"
    t.integer  "venue_id"
    t.float    "rating"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "venue_ratings", ["user_id"], name: "index_venue_ratings_on_user_id", using: :btree
  add_index "venue_ratings", ["venue_id"], name: "index_venue_ratings_on_venue_id", using: :btree

  create_table "venues", force: true do |t|
    t.string   "name"
    t.float    "rating"
    t.string   "phone_number"
    t.text     "address"
    t.string   "city"
    t.string   "state"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.float    "latitude"
    t.float    "longitude"
    t.string   "country"
    t.string   "postal_code"
    t.text     "formatted_address"
    t.datetime "fetched_at"
    t.float    "r_up_votes",                           default: 1.0
    t.float    "r_down_votes",                         default: 1.0
    t.string   "menu_link"
    t.float    "color_rating",                         default: -1.0
    t.integer  "key",                        limit: 8
    t.string   "time_zone"
    t.integer  "outstanding_bounties",                 default: 0
    t.string   "l_sphere"
    t.datetime "latest_posted_comment_time"
    t.boolean  "is_address",                           default: false
    t.boolean  "has_been_voted_at",                    default: false
    t.datetime "latest_placed_bounty_time"
    t.float    "popularity_rank"
    t.float    "popularity_percentile"
    t.float    "page_views",                           default: 0.0
    t.integer  "user_id"
    t.integer  "instagram_location_id"
    t.datetime "last_instagram_pull_time"
    t.boolean  "verified",                             default: true
    t.datetime "last_page_view_time"
  end

  add_index "venues", ["instagram_location_id"], name: "index_venues_on_instagram_location_id", using: :btree
  add_index "venues", ["key"], name: "index_venues_on_key", using: :btree
  add_index "venues", ["l_sphere"], name: "index_venues_on_l_sphere", using: :btree
  add_index "venues", ["latitude"], name: "index_venues_on_latitude", using: :btree
  add_index "venues", ["longitude"], name: "index_venues_on_longitude", using: :btree

end
