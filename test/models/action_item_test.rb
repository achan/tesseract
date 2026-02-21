require "test_helper"

class ActionItemTest < ActiveSupport::TestCase
  test "validates description presence" do
    item = ActionItem.new(
      summary: summaries(:recent_summary),
      source: slack_channels(:general),
      status: "untriaged"
    )
    assert_not item.valid?
    assert_includes item.errors[:description], "can't be blank"
  end

  test "validates status inclusion" do
    item = ActionItem.new(
      summary: summaries(:recent_summary),
      source: slack_channels(:general),
      description: "Test",
      status: "invalid"
    )
    assert_not item.valid?
    assert_includes item.errors[:status], "is not included in the list"
  end

  test "accepts all valid statuses" do
    ActionItem::STATUSES.each do |status|
      item = ActionItem.new(
        source: slack_channels(:general),
        description: "Test #{status}",
        status: status
      )
      assert item.valid?, "Expected status '#{status}' to be valid"
    end
  end

  test "untriaged_items scope returns only untriaged items" do
    items = ActionItem.untriaged_items
    assert items.all? { |i| i.status == "untriaged" }
  end

  test "active_items scope returns untriaged, open, backlog, and in_progress items" do
    items = ActionItem.active_items
    assert items.all? { |i| i.status.in?(%w[untriaged open backlog in_progress]) }
  end
end
