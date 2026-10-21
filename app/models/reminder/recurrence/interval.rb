# Every so many days, weeks, months, or years ("every 3 days", "every 6 months"), counted from the day each
# occurrence is done: vitamins taken a day late come due again three days after they were actually taken.
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
    at(done_at.to_date.advance(@step))
  end

  private

  def at(date)
    Reminder::Clock.at(date, @clock)
  end
end
