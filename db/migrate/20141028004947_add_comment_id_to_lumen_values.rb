class AddCommentIdToLumenValues < ActiveRecord::Migration
  def change
  	add_column :lumen_values, :comment_id, :integer
  end
end
