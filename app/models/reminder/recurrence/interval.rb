# Every so many days, weeks, months, or years ("every 3 days", "every 6 months"), counted from the day each
# occurrence is done: vitamins taken a day late come due again three days after they were actually taken. Months and
# years keep to the day the repeat started on: one started on January 31st comes due on February 28th, then March
# 31st.
class Reminder::Recurrence::Interval
  PATTERN = /\A(?:(?<count>other|\d+|[a-z]+)\s+)?(?<unit>day|week|month|year)s?\z/

  def self.parse(body, clock:, anchor:)
    match = PATTERN.match(body) or return
    count = Reminder::Recurrence.count(match[:count])
    return unless count&.positive?

    step = match[:unit] == "week" ? { days: count * 7 } : { "#{match[:unit]}s": count }
    new(clock:, anchor:, step:)
  end

  def initialize(clock:, anchor:, step:)
    @clock = clock
    @anchor = anchor
    @step = step
  end

  # Without an anchor, the next time the clock comes round: today, or tomorrow if that's passed.
  def first_time(now)
    return at(@anchor) if @anchor

    [now.to_date, now.to_date + 1].map { at(it) }.find { it > now }
  end

  def next_time(occurrence:, done_at:) # rubocop:disable Lint/UnusedMethodArgument
    done_on = done_at.to_date
    date = done_on.advance(@step)
    at(shortened?(done_on) ? date.change(day: [@anchor.day, date.end_of_month.day].min) : date)
  end

  private

  # Done on the last day of a month too short for the day it started on, so the next month gets that day back.
  def shortened?(done_on)
    (@step.key?(:months) || @step.key?(:years)) && @anchor && done_on == done_on.end_of_month &&
      @anchor.day > done_on.day
  end

  def at(date)
    Reminder::Clock.at(date, @clock)
  end
end
