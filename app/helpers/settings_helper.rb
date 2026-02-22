module SettingsHelper
  def health_dot(status)
    color = case status
    when :green  then "bg-green-500"
    when :yellow then "bg-yellow-500"
    when :red    then "bg-red-500"
    else              "bg-gray-400"
    end
    tag.span(class: "inline-block w-2.5 h-2.5 shrink-0 rounded-full #{color}")
  end

  def health_time_status(time, green_threshold: 1.hour, yellow_threshold: 24.hours)
    if time.nil?
      [:red, "Never"]
    elsif time > green_threshold.ago
      [:green, time_ago_label(time)]
    elsif time > yellow_threshold.ago
      [:yellow, time_ago_label(time)]
    else
      [:red, time_ago_label(time)]
    end
  end

  def time_ago_label(time)
    relative = short_time_ago(time)
    relative == "now" ? "just now" : "#{relative} ago"
  end
end
