class FeedSource < ApplicationRecord
  belongs_to :feed
  belongs_to :source, polymorphic: true

  def auto_include_new_channels?
    options["auto_include_new_channels"] == true
  end

  def include_dms?
    options["include_dms"] == true
  end
end
