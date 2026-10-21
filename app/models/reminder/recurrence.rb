# How a repeating reminder repeats: every so many days, or on certain weekdays, at a time of day.
class Reminder::Recurrence
  INTERVAL = /\Aevery\s+(?:(?<other>other)\s+|#{Reminder::Directive::COUNT}\s+)?(?<unit>day|week)s?\z/
  WEEKDAY_LIST = /\Aevery\s+(?<days>[a-z&\s]+)\z/

  # nil unless the rule is one of "every [other | N] day(s) / week(s)", "every weekday", or a list of weekdays
  # ("every monday and thursday").
  def self.parse(rule, clock)
    if (days = interval_days(rule))
      new(clock:, days:)
    elsif (weekdays = weekdays_in(rule))
      new(clock:, weekdays:)
    end
  end

  def self.interval_days(rule)
    match = INTERVAL.match(rule) or return
    count = match[:other] ? 2 : Reminder::Directive.count(match[:count] || "1")
    count * (match[:unit] == "week" ? 7 : 1) if count&.positive?
  end

  def self.weekdays_in(rule)
    return (1..5).to_a if rule == "every weekday"

    match = WEEKDAY_LIST.match(rule) or return
    names = match[:days].split(/\s+|&/).compact_blank - ["and"]
    weekdays = names.map { |name| Reminder::Directive::WEEKDAYS.index { it.start_with?(name) } if name.length >= 3 }
    weekdays.sort.uniq if weekdays.any? && weekdays.none?(nil)
  end
  private_class_method :interval_days, :weekdays_in

  def initialize(clock:, days: nil, weekdays: nil)
    @clock = clock
    @days = days
    @weekdays = weekdays
  end

  # The first occurrence after now: today if its time hasn't passed, otherwise the next day it's due.
  def first_time(now)
    next_after(now)
  end

  # The occurrence after the one just done. Weekday reminders move to the next scheduled day after both the
  # occurrence and when it was done; interval reminders count from the day it was done, so vitamins taken a day late
  # come due again N days after they were actually taken.
  def next_time(occurrence:, done_at:)
    if @days
      Reminder::Clock.at(done_at.to_date + @days, @clock)
    else
      next_after([occurrence, done_at].max)
    end
  end

  private

  def next_after(time)
    (0..7).lazy.map { time.to_date + it }
      .select { @days || @weekdays.include?(it.wday) }
      .map { Reminder::Clock.at(it, @clock) }
      .find { it > time }
  end
end
