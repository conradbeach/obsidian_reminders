module RemindersHelper
  def reminder_day_heading(date)
    today = Time.zone.today

    if date == today then "Today"
    elsif date == today - 1 then "Yesterday"
    elsif date == today + 1 then "Tomorrow"
    elsif date < today + 7 then date.strftime("%A")
    elsif date.year == today.year then date.strftime("%a, %b %-d")
    else date.strftime("%a, %b %-d, %Y")
    end
  end
end
