# The time in a reminder's directive: the "tomorrow 9am" in "(@tomorrow 9am)". Anything it doesn't recognize has no
# time rather than a guessed one.
class Reminder::Directive
  # Reminders with only a date ("friday", "Oct 21") go off at 9am.
  DATE_ONLY_HOUR = 9

  WEEKDAYS = Date::DAYNAMES.map(&:downcase)
  MONTHS = Date::MONTHNAMES.compact.map(&:downcase)
  COUNTS = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
    .each.with_index(1).to_h.merge("a" => 1, "an" => 1)

  COUNT = /(?<count>\d+|[a-z]+)/
  CLOCK = /(?:at\s+)?(?<clock>noon|\d{1,2}(?::\d{2})?\s*[ap]m|\d{1,2}:\d{2})/
  CLOCK_AT_END = /(?:\A|\s+)#{CLOCK}\z/
  CLOCK_AT_START = /\A#{CLOCK}(?:\s+|\z)/
  DURATION = /\Ain\s+#{COUNT}\s+(?<unit>minute|min|hour|hr)s?\z/
  DATE_OFFSET = /\Ain\s+#{COUNT}\s+(?<unit>day|week|month)s?\z/
  WEEKDAY = /\A(?:(?<modifier>this|next)\s+)?(?<name>[a-z]{3,})\z/
  CALENDAR_DATES = [
    /\A(?<year>\d{4})-(?<month>\d{1,2})-(?<day>\d{1,2})\z/,
    %r{\A(?<month>\d{1,2})/(?<day>\d{1,2})(?:/(?<year>\d{4}|\d{2}))?\z},
    /\A(?<month>[a-z]{3,})\.?\s+(?<day>\d{1,2})(?:st|nd|rd|th)?(?:\s+(?<year>\d{4}))?\z/,
    /\A(?<day>\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(?<month>[a-z]{3,})\.?(?:\s+(?<year>\d{4}))?\z/,
  ].freeze

  def initialize(text, now: Time.current)
    @text = text.downcase.gsub(/\b([ap])\.m\.?/, '\1m').tr(",", " ").squish
    @now = now
  end

  # Times found for the first time are relative to now. A time of day without a date is the next one, so "9am" in
  # the evening is tomorrow morning; a weekday ("friday 5pm") likewise moves to next week once its time has passed.
  def time
    return if @text.empty?
    return duration_from_now if DURATION.match?(@text)

    date_text, clock = split_clock
    date, roll = date_and_roll(date_text.delete_prefix("on ").strip)
    return unless date

    clock ||= [DATE_ONLY_HOUR, 0]
    time = at(date, clock)
    roll && time <= @now ? at(date.advance(roll), clock) : time
  end

  private

  def at(date, (hour, minute))
    Time.zone.local(date.year, date.month, date.day, hour, minute)
  end

  def duration_from_now
    match = DURATION.match(@text)
    count = count(match[:count]) or return
    @now.change(sec: 0) + (match[:unit].start_with?("h") ? count.hours : count.minutes)
  end

  # Splits a valid time of day off either end of the text.
  def split_clock
    match = CLOCK_AT_END.match(@text) || CLOCK_AT_START.match(@text)
    clock = match && parse_clock(match[:clock])
    clock ? [match.pre_match + match.post_match, clock] : [@text, nil]
  end

  def parse_clock(text)
    return [12, 0] if text == "noon"

    hour, minute, meridiem = text.match(/(\d+)(?::(\d+))?\s*([ap]m)?/).captures
    hour = twenty_four_hour(hour.to_i, meridiem) or return
    [hour, minute.to_i] if hour < 24 && minute.to_i < 60
  end

  def twenty_four_hour(hour, meridiem)
    return hour unless meridiem

    (hour % 12) + (meridiem == "pm" ? 12 : 0) if hour.between?(1, 12)
  end

  # The date, and how far to move it if its time has already passed today.
  def date_and_roll(text)
    today = @now.to_date

    case text
    when "" then [today, { days: 1 }] # A time without a date
    when "today" then [today]
    when "tomorrow" then [today + 1]
    when DATE_OFFSET then date_offset(today, Regexp.last_match)
    when WEEKDAY then weekday(today, Regexp.last_match)
    else calendar_date(today, text)
    end
  end

  def date_offset(today, match)
    count = count(match[:count]) or return
    [today.advance(match[:unit].pluralize.to_sym => count)]
  end

  def weekday(today, match)
    wday = WEEKDAYS.index { it.start_with?(match[:name]) } or return
    days_ahead = (wday - today.wday) % 7

    if match[:modifier] == "next"
      [today + (days_ahead.zero? ? 7 : days_ahead)]
    else
      [today + days_ahead, { weeks: 1 }]
    end
  end

  # Without a year, the date's next occurrence.
  def calendar_date(today, text)
    match = CALENDAR_DATES.lazy.filter_map { it.match(text) }.first or return
    year = year(match[:year])
    date = valid_date(year || today.year, month(match[:month]), match[:day].to_i) or return
    [date < today && !year ? date.next_year : date]
  end

  def valid_date(year, month, day)
    Date.new(year, month, day) if month && Date.valid_date?(year, month, day)
  end

  def year(text)
    text && (text.length == 2 ? 2000 + text.to_i : text.to_i)
  end

  def month(text)
    Integer(text, 10, exception: false) || MONTHS.index { it.start_with?(text) }&.succ
  end

  def count(text)
    Integer(text, 10, exception: false) || COUNTS[text]
  end
end
