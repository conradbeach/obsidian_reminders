# Dates fixed by the calendar: weekdays ("every monday and thursday", "every weekday"), dates each year ("every
# year on october 1", "every april 19", "every sep 1, dec 1, mar 1 and jun 1") or month ("every month on the
# 15th"), or the nth weekday of a month or of every month ("every last saturday in october", "every 2nd tue"). Done
# moves to the next scheduled date.
class Reminder::Recurrence::Calendar
  ORDINAL = /(?<nth>1st|2nd|3rd|4th|5th|first|second|third|fourth|fifth|last)/
  ORDINALS = { "1st" => 1, "first" => 1, "2nd" => 2, "second" => 2, "3rd" => 3, "third" => 3, "4th" => 4,
               "fourth" => 4, "5th" => 5, "fifth" => 5, "last" => :last }.freeze
  DAY_OF_MONTH = /\A(?<day>\d{1,2})(?:st|nd|rd|th)?\z/
  MONTHLY_DATE = /\A(?:month\s+on\s+)?(?:the\s+)?(?<day>\d{1,2})(?:st|nd|rd|th)\z/
  IN_MONTH = /(?:\s+(?:of|in)\s+(?<month>[a-z]+))?/
  NTH_WEEKDAY = /\A(?:(?:year|month)\s+on\s+)?(?:the\s+)?#{ORDINAL}\s+(?<day>[a-z]+)#{IN_MONTH}\z/
  # Far enough ahead to find the next February 29th.
  SEARCH_DAYS = 366 * 8

  def self.parse(body, clock:, anchor:)
    rule = weekdays(body) || yearly_dates(body) || monthly_date(body) || nth_weekday(body) or return
    new(clock:, anchor:, rule:)
  end

  def self.weekdays(body)
    return ->(date) { date.on_weekday? } if body == "weekday"

    days = (body.split(/\s+|&/) - ["", "and"]).map { Reminder::Recurrence.weekday(it) }
    ->(date) { days.include?(date.wday) } if days.any? && days.none?(nil)
  end

  # One or more month-and-day pairs, in either order ("april 19", "the 1st of september").
  def self.yearly_dates(body)
    words = body.delete_prefix("year on ").tr("&", " ").split - ["and", "the", "of"]
    return unless words.any? && words.size.even?

    dates = words.each_slice(2).map { |pair| month_and_day(*pair) }
    ->(date) { dates.include?([date.month, date.day]) } if dates.none?(nil)
  end

  def self.month_and_day(first, second)
    month_name, day_text = first.match?(DAY_OF_MONTH) ? [second, first] : [first, second]
    month = Reminder::Recurrence.month(month_name.delete_suffix("."))
    day = DAY_OF_MONTH.match(day_text)&.[](:day)&.to_i
    [month, day] if month && day && Date.valid_date?(2028, month, day)
  end

  def self.monthly_date(body)
    match = MONTHLY_DATE.match(body) or return
    day = match[:day].to_i
    ->(date) { date.day == day } if day.between?(1, 31)
  end

  def self.nth_weekday(body)
    match = NTH_WEEKDAY.match(body) or return
    weekday = Reminder::Recurrence.weekday(match[:day])
    month = match[:month] && Reminder::Recurrence.month(match[:month])
    nth_weekday_rule(ORDINALS[match[:nth]], weekday, month) if weekday && (month || !match[:month])
  end

  def self.nth_weekday_rule(nth, weekday, month)
    ->(date) { date.wday == weekday && (!month || date.month == month) && nth_of_month?(date, nth) }
  end

  def self.nth_of_month?(date, nth)
    nth == :last ? date + 7 > date.end_of_month : (date.day - 1) / 7 == nth - 1
  end
  private_class_method :weekdays, :yearly_dates, :month_and_day, :monthly_date, :nth_weekday, :nth_weekday_rule,
    :nth_of_month?

  def initialize(clock:, anchor:, rule:)
    @clock = clock
    @anchor = anchor
    @rule = rule
  end

  # With an anchor, that date exactly, even if it's past or off the schedule (a rescheduled occurrence).
  def first_time(now)
    @anchor ? at(@anchor) : next_after(now)
  end

  def next_time(occurrence:, done_at:)
    next_after([occurrence, done_at].max)
  end

  private

  def next_after(time)
    dates_from(time.to_date).map { at(it) }.find { it > time }
  end

  def dates_from(date)
    (0..SEARCH_DAYS).lazy.map { date + it }.select { @rule.call(it) }
  end

  def at(date)
    Reminder::Clock.at(date, @clock)
  end
end
