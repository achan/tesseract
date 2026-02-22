class Profile < ApplicationRecord
  has_many :workspaces, dependent: :restrict_with_error

  validates :name, presence: true
end
