namespace :action_items do
  desc "Archive all currently active action items"
  task archive_all: :environment do
    timestamp = Time.current
    active_count = ActionItem.active.count
    archived_count = ActionItem.archived.count

    updated_count = ActionItem.active.update_all(archived_at: timestamp, updated_at: timestamp)

    puts "Archived #{updated_count} action item#{'s' unless updated_count == 1}."
    puts "Previously archived: #{archived_count}"
    puts "Total archived: #{archived_count + updated_count}"
    puts "Remaining active: #{active_count - updated_count}"
  end
end
