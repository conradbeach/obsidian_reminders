# A time of day in a directive: "9am", "9:30 pm", "21:00", "noon", optionally after "at".
module Reminder::Clock
  CLOCK = /(?:at\s+)?(?<clock>noon|\d{1,2}(?::\d{2})?\s*[ap]m|\d{1,2}:\d{2})/
  AT_END = /(?:\A|\s+)#{CLOCK}\z/
  AT_START = /\A#{CLOCK}(?:\s+|\z)/

  # Splits a valid time of day off either end of the text, returning the rest and [hour, minute] (nil if none).
  def self.split(text)
    match = AT_END.match(text) || AT_START.match(text)
    clock = match && parse(match[:clock])
    clock ? [match.pre_match + match.post_match, clock] : [text, nil]
  end

  def self.parse(text)
    return [12, 0] if text == "noon"

    hour, minute, meridiem = text.match(/(\d+)(?::(\d+))?\s*([ap]m)?/).captures
    hour = twenty_four_hour(hour.to_i, meridiem) or return
    [hour, minute.to_i] if hour < 24 && minute.to_i < 60
  end

  def self.twenty_four_hour(hour, meridiem)
    return hour unless meridiem

    (hour % 12) + (meridiem == "pm" ? 12 : 0) if hour.between?(1, 12)
  end
  private_class_method :parse, :twenty_four_hour

  def self.at(date, (hour, minute))
    Time.zone.local(date.year, date.month, date.day, hour, minute)
  end
end
