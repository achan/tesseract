module SettingsHelper
  def health_dot(status)
    color = case status
    when :green  then "bg-green-500"
    when :yellow then "bg-yellow-500"
    when :red    then "bg-red-500"
    else              "bg-gray-400"
    end
    tag.span(class: "inline-block w-2.5 h-2.5 rounded-full #{color}")
  end

  def health_time_status(time, green_threshold: 1.hour, yellow_threshold: 24.hours)
    if time.nil?
      [:red, "Never"]
    elsif time > green_threshold.ago
      [:green, "#{short_time_ago(time)} ago"]
    elsif time > yellow_threshold.ago
      [:yellow, "#{short_time_ago(time)} ago"]
    else
      [:red, "#{short_time_ago(time)} ago"]
    end
  end
end
