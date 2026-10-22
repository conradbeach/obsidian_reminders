# Dates fixed by the calendar: weekdays ("every monday and thursday", "every weekday"), dates each year ("every
# year on october 1", "every april 19", "every sep 1, dec 1, mar 1 and jun 1") or month ("every month on the
# 15th"), or the nth weekday of some months or of every month ("every last saturday in october", "every 3rd sat in
# jan, jun and nov", "every 2nd tue"), or any of these joined with "and" ("every 2nd saturday in november and 2nd
# saturday in may"). Done moves to the next scheduled date.
class Reminder::Recurrence::Calendar
  ORDINAL = /(?<nth>1st|2nd|3rd|4th|5th|first|second|third|fourth|fifth|last)/
  ORDINALS = { "1st" => 1, "first" => 1, "2nd" => 2, "second" => 2, "3rd" => 3, "third" => 3, "4th" => 4,
               "fourth" => 4, "5th" => 5, "fifth" => 5, "last" => :last }.freeze
  DAY_OF_MONTH = /\A(?<day>\d{1,2})(?:st|nd|rd|th)?\z/
  MONTHLY_DATE = /\A(?<day>\d{1,2})(?:st|nd|rd|th)\z/
  IN_MONTHS = /(?:\s+(?:of|in)\s+(?<months>[a-z.]+(?:\s+[a-z.]+)*))?/
  NTH_WEEKDAY = /\A(?:(?:year|month)\s+on\s+)?(?:the\s+)?#{ORDINAL}\s+(?<day>[a-z]+)#{IN_MONTHS}\z/
  SEPARATOR = /\s+and\s+|\s*&\s*/
  # "and" in a list of months ("in jan, jun and nov") joins months, not rules.
  AND_BEFORE_MONTH = /(?<=[a-z.])#{SEPARATOR}(?=(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?(?:\s|\z))/
  BARE_ORDINAL = /\A(?:(?:year|month)\s+on\s+)?(?:the\s+)?#{ORDINAL}\z/
  UP_TO_ORDINAL = /\A.*?#{ORDINAL}/
  # Far enough ahead to find the next February 29th.
  SEARCH_DAYS = 366 * 8

  # A date is on the schedule if any of the rules joined with "and" puts it there.
  def self.parse(body, clock:, anchor:)
    rules = parts(body).map { rule(it) }
    return unless rules.any? && rules.none?(nil)

    new(clock:, anchor:, rule: ->(date) { rules.any? { |rule| rule.call(date) } })
  end

  # The rules joined with "and". Ordinals before an nth weekday share its weekday: "2nd and 4th monday" is the 2nd
  # monday and the 4th monday, not the 2nd of the month and the 4th monday.
  def self.parts(body)
    parts = body.gsub(AND_BEFORE_MONTH, " ").split(SEPARATOR)
    return parts unless parts.last&.match?(NTH_WEEKDAY)

    weekday = parts.last.sub(UP_TO_ORDINAL, "")
    parts.map { it.match?(BARE_ORDINAL) ? "#{it}#{weekday}" : it }
  end

  # A day of the month, as a date test: "the 1st", "the third sunday".
  def self.day_of_month(body)
    monthly_dates(body) || nth_weekday(body)
  end

  def self.rule(body)
    weekdays(body) || yearly_dates(body) || monthly_dates(body) || nth_weekday(body)
  end

  def self.weekdays(body)
    return ->(date) { date.on_weekday? } if body == "weekday"

    days = body.split.map { Reminder::Recurrence.weekday(it) }
    ->(date) { days.include?(date.wday) } if days.any? && days.none?(nil)
  end

  # One or more month-and-day pairs, in either order ("april 19", "the 1st of september").
  def self.yearly_dates(body)
    words = body.delete_prefix("year on ").split - ["the", "of"]
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

  # One or more days of the month ("the 15th", "1st 15th").
  def self.monthly_dates(body)
    days = (body.delete_prefix("month on ").split - ["the"]).map { MONTHLY_DATE.match(it)&.[](:day)&.to_i }
    ->(date) { days.include?(date.day) } if days.any? && days.all? { it&.between?(1, 31) }
  end

  def self.nth_weekday(body)
    match = NTH_WEEKDAY.match(body) or return
    weekday = Reminder::Recurrence.weekday(match[:day])
    months = match[:months]&.split&.map { Reminder::Recurrence.month(it.delete_suffix(".")) }
    nth_weekday_rule(ORDINALS[match[:nth]], weekday, months) if weekday && !months&.include?(nil)
  end

  # Without months, every month.
  def self.nth_weekday_rule(nth, weekday, months)
    ->(date) { date.wday == weekday && (!months || months.include?(date.month)) && nth_of_month?(date, nth) }
  end

  def self.nth_of_month?(date, nth)
    nth == :last ? date + 7 > date.end_of_month : (date.day - 1) / 7 == nth - 1
  end
  private_class_method :parts, :rule, :weekdays, :yearly_dates, :month_and_day, :monthly_dates, :nth_weekday,
    :nth_weekday_rule, :nth_of_month?

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
