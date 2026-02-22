class Profile < ApplicationRecord
  has_many :workspaces, dependent: :restrict_with_error
  has_many :action_items, as: :source
  has_many :overviews, dependent: :destroy

  validates :name, presence: true
end
