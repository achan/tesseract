require "test_helper"

class ActionItemTest < ActiveSupport::TestCase
  test "validates description presence when source is a profile" do
    item = ActionItem.new(
      source: profiles(:one),
      status: "untriaged",
      priority: 3
    )
    assert_not item.valid?
    assert_includes item.errors[:description], "can't be blank"
  end

  test "allows blank description when source is a slack channel" do
    item = ActionItem.new(
      source: slack_channels(:general),
      status: "untriaged",
      priority: 3
    )
    assert item.valid?
  end

  test "allows blank description when source is a slack event" do
    item = ActionItem.new(
      source: slack_events(:message_one),
      status: "untriaged",
      priority: 3
    )
    assert item.valid?
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

  test "active scope returns only non-archived items" do
    items = ActionItem.active
    assert items.all? { |i| i.archived_at.nil? }
    assert items.any?, "should have active items"
  end

  test "archived scope returns only archived items" do
    items = ActionItem.archived
    assert items.all? { |i| i.archived_at.present? }
    assert items.any?, "should have archived items"
  end

  test "archive! sets archived_at" do
    item = action_items(:untriaged_item)
    assert_nil item.archived_at
    item.archive!
    assert_not_nil item.reload.archived_at
  end

  test "unarchive! clears archived_at" do
    item = action_items(:archived_item)
    assert_not_nil item.archived_at
    item.unarchive!
    assert_nil item.reload.archived_at
  end

  test "archived? returns correct value" do
    assert action_items(:archived_item).archived?
    assert_not action_items(:untriaged_item).archived?
  end

  test "requires description for manually created items" do
    item = ActionItem.new(
      source: profiles(:one),
      status: "todo",
      priority: 3
    )
    assert_not item.valid?
    assert_includes item.errors[:description], "can't be blank"
  end
end
