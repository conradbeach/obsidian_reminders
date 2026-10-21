# Every few weeks on a weekday ("every 2 weeks on tuesday"), keeping to the schedule however late an occurrence is
# done.
class Reminder::Recurrence::WeeklyInterval
  PATTERN = /\A(?<count>other|\d+|[a-z]+)\s+weeks?\s+(?:on\s+)?(?<day>[a-z]+)\z/

  def self.parse(body, clock:, anchor:)
    match = PATTERN.match(body) or return
    count = Reminder::Recurrence.count(match[:count])
    weekday = Reminder::Recurrence.weekday(match[:day])
    new(clock:, anchor:, weeks: count, weekday:) if count&.positive? && weekday
  end

  def initialize(clock:, anchor:, weeks:, weekday:)
    @clock = clock
    @anchor = anchor
    @weeks = weeks
    @weekday = weekday
  end

  def first_time(now)
    return at(@anchor) if @anchor

    (0..7).lazy.map { now.to_date + it }.select { it.wday == @weekday }.map { at(it) }.find { it > now }
  end

  def next_time(occurrence:, done_at:)
    date = occurrence.to_date
    date += @weeks * 7 until at(date) > [occurrence, done_at].max
    at(date)
  end

  private

  def at(date)
    Reminder::Clock.at(date, @clock)
  end
end
