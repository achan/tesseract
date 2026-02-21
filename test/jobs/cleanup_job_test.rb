require "test_helper"

class CleanupJobTest < ActiveSupport::TestCase
  test "deletes old events and keeps recent ones" do
    assert SlackEvent.exists?(event_id: "Ev_OLD_001")
    CleanupJob.perform_now
    assert_not SlackEvent.exists?(event_id: "Ev_OLD_001"), "Old event should be deleted"
    assert SlackEvent.exists?(event_id: "Ev_MSG_001"), "Recent event should remain"
  end

  test "does not delete summaries or action items" do
    old_summary = summaries(:old_summary)
    old_open = action_items(:old_untriaged_item)
    old_done = action_items(:old_done_item)

    CleanupJob.perform_now

    assert Summary.exists?(old_summary.id), "Summaries should not be touched"
    assert ActionItem.exists?(old_open.id), "Action items should not be touched"
    assert ActionItem.exists?(old_done.id), "Action items should not be touched"
  end

  test "auto-archives old wont_fix items" do
    old_wont_fix = ActionItem.create!(
      description: "Old wont fix",
      status: "wont_fix",
      priority: 3,
      source: slack_channels(:general),
      updated_at: 2.days.ago
    )
    recent_wont_fix = ActionItem.create!(
      description: "Recent wont fix",
      status: "wont_fix",
      priority: 3,
      source: slack_channels(:general)
    )

    CleanupJob.perform_now

    assert old_wont_fix.reload.archived?, "Old wont_fix item should be archived"
    assert_not recent_wont_fix.reload.archived?, "Recent wont_fix item should not be archived"
  end
end
