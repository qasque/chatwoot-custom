class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string unless column_exists?(:conversations, :cached_label_list)

    Conversation.reset_column_information

    # acts-as-taggable-on 12+ uses Taggable::Caching and exposes initialize_tags_cache on the model;
    # older gems used Taggable::Cache.included(Conversation).
    if Conversation.respond_to?(:initialize_tags_cache)
      Conversation.initialize_tags_cache
    elsif defined?(ActsAsTaggableOn::Taggable::Cache)
      ActsAsTaggableOn::Taggable::Cache.included(Conversation)
    end
  end
end
