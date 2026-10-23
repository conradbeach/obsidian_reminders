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
  DURATION = /\Ain\s+#{COUNT}\s+(?<unit>minute|min|hour|hr)s?\z/
  DATE_OFFSET = /\Ain\s+#{COUNT}\s+(?<unit>day|week|month)s?\z/
  WEEKDAY = /\A(?:(?<modifier>this|next)\s+)?(?<name>[a-z]{3,})\z/
  CALENDAR_DATES = [
    /\A(?<year>\d{4})-(?<month>\d{1,2})-(?<day>\d{1,2})\z/,
    %r{\A(?<month>\d{1,2})/(?<day>\d{1,2})(?:/(?<year>\d{4}|\d{2}))?\z},
    /\A(?<month>[a-z]{3,})\.?\s+(?<day>\d{1,2})(?:st|nd|rd|th)?(?:\s+(?<year>\d{4}))?\z/,
    /\A(?<day>\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(?<month>[a-z]{3,})\.?(?:\s+(?<year>\d{4}))?\z/,
  ].freeze

  def self.count(text)
    Integer(text, 10, exception: false) || COUNTS[text]
  end

  def initialize(text, now: Time.current)
    @text = text.downcase.gsub(/(?<![a-z])([ap])\.m\.?/, '\1m').tr(",", " ").squish
    @now = now
  end

  # Times found for the first time are relative to now. A time of day without a date is the next one, so "9am" in
  # the evening is tomorrow morning; a weekday ("friday 5pm") likewise moves to next week once its time has passed.
  # A repeating reminder's time is its first occurrence.
  def time
    return if @text.empty?
    return recurrence&.first_time(@now) if recurring?
    return duration_from_now if DURATION.match?(@text)

    date_and_clock_time
  end

  # How the reminder repeats ("every monday and thursday at 7pm", "every 6 months from 2027-03-01"), or nil if it
  # doesn't or isn't understood.
  def recurrence
    return unless recurring?

    rule, start = @text.split(/\s+(?:from|starting)\s+/, 2)
    anchor, anchor_clock = start ? starting(start) : []
    return if start && !anchor

    rule, clock = Reminder::Clock.split(rule)
    Reminder::Recurrence.parse(rule, clock || anchor_clock || [DATE_ONLY_HOUR, 0], anchor:)
  end

  private

  # The starting date, and the time of day if it follows the date rather than the rule: "every day from monday at
  # 8am" as well as "every day at 8am from monday".
  def starting(text)
    date_text, clock = Reminder::Clock.split(text)
    [self.class.new(date_text, now: @now).time&.to_date, clock]
  end

  def date_and_clock_time
    date_text, clock = Reminder::Clock.split(@text)
    date, roll = date_and_roll(date_text.delete_prefix("on ").strip)
    return unless date

    clock ||= [DATE_ONLY_HOUR, 0]
    time = at(date, clock)
    roll && time <= @now ? at(date.advance(roll), clock) : time
  end

  def recurring?
    @text.start_with?("every ")
  end

  def at(date, clock)
    Reminder::Clock.at(date, clock)
  end

  def duration_from_now
    match = DURATION.match(@text)
    count = self.class.count(match[:count]) or return
    @now.change(sec: 0) + (match[:unit].start_with?("h") ? count.hours : count.minutes)
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
    count = self.class.count(match[:count]) or return
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
end
