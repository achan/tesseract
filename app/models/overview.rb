class Overview < ApplicationRecord
  belongs_to :profile, optional: true

  after_create_commit :broadcast_replace

  private

  def broadcast_replace
    broadcast_replace_to(
      "dashboard_overview",
      target: "dashboard_overview",
      partial: "dashboard/overview",
      locals: { overview: self }
    )
  end
end
