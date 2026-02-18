require "test_helper"

class CleanupJobTest < ActiveSupport::TestCase
  test "deletes old events" do
    assert SlackEvent.exists?(event_id: "Ev_OLD_001")
    CleanupJob.perform_now
    assert_not SlackEvent.exists?(event_id: "Ev_OLD_001"), "Old event should be deleted"
    assert SlackEvent.exists?(event_id: "Ev_MSG_001"), "Recent event should remain"
  end

  test "deletes old summaries without open action items" do
    old_summary = summaries(:old_summary)
    recent_summary = summaries(:recent_summary)

    CleanupJob.perform_now

    # old_summary still has an open action item, so it should be kept
    assert Summary.exists?(old_summary.id), "Old summary with open items should be kept"
    assert Summary.exists?(recent_summary.id), "Recent summary should remain"
  end

  test "deletes old non-open action items but keeps open ones" do
    old_open = action_items(:old_open_item)
    old_done = action_items(:old_done_item)

    CleanupJob.perform_now

    assert ActionItem.exists?(old_open.id), "Old open item should be kept"
    assert_not ActionItem.exists?(old_done.id), "Old done item should be deleted"
  end
end
