class AllowNullSourceIdForTrafficSourcePrompts < ActiveRecord::Migration[7.1]
  def change
    change_column_null :traffic_source_prompts, :source_id, true
  end
end
