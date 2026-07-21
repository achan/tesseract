class SettingsController < ApplicationController
  def show
    now = Time.current

    last_event = SlackEvent.maximum(:created_at)
    last_summary = Summary.maximum(:created_at)
    last_action_item = ActionItem.maximum(:created_at)

    deploy_log = Rails.root.join("log/deploy.log")
    last_deploy = deploy_log.exist? ? File.mtime(deploy_log) : nil

    failed_jobs = SolidQueue::FailedExecution.count
    queue_processes = SolidQueue::Process.where("last_heartbeat_at > ?", 5.minutes.ago)

    last_cleanup_run = SolidQueue::Job
      .where(class_name: "CleanupJob")
      .where.not(finished_at: nil)
      .maximum(:finished_at)

    in_progress_jobs = SolidQueue::ClaimedExecution.count
    total_queued = SolidQueue::ReadyExecution.count

    db_path = ActiveRecord::Base.connection_db_config.database
    db_size = File.exist?(db_path) ? File.size(db_path) : nil

    @remote_control_session = RemoteControlSession.current

    @health = {
      deploy: { configured: ENV["GITHUB_WEBHOOK_SECRET"].present?, last_deploy: last_deploy },
      slack_events: { last_received: last_event },
      summarization: {
        last_run: last_summary,
        failed: SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { class_name: "SummarizeJob" }).count
      },
      action_items: {
        last_run: last_action_item,
        failed: SolidQueue::FailedExecution.joins(:job).where(solid_queue_jobs: { class_name: "GenerateActionItemsJob" }).count
      },
      cleanup: { last_run: last_cleanup_run },
      queue: { workers_alive: queue_processes.count, failed_jobs: failed_jobs, in_progress: in_progress_jobs, queued: total_queued },
      database: { size: db_size }
    }
  end

  def logout
    cookies.delete(:authenticated)
    head :unauthorized
  end
end
