# Every few months on a day of the month ("every 3 months on the third sunday", "every 2 months on the 1st"), keeping
# to the schedule however late an occurrence is done.
class Reminder::Recurrence::MonthlyInterval
  PATTERN = /\A(?<count>other|\d+|[a-z]+)\s+months?\s+on\s+(?<day>.+)\z/
  # Far enough ahead to find a day that isn't in every month, like the 31st.
  SEARCH_DAYS = 366

  def self.parse(body, clock:, anchor:)
    match = PATTERN.match(body) or return
    count = Reminder::Recurrence.count(match[:count])
    day = Reminder::Recurrence::Calendar.day_of_month(match[:day])
    new(clock:, anchor:, months: count, day:) if count&.positive? && day
  end

  def initialize(clock:, anchor:, months:, day:)
    @clock = clock
    @anchor = anchor
    @months = months
    @day = day
  end

  def first_time(now)
    return at(@anchor) if @anchor

    days_from(now.to_date).map { at(it) }.find { it > now }
  end

  # The day in the month so many months after the occurrence's, skipping ahead until it's past both the occurrence
  # and when it was done.
  def next_time(occurrence:, done_at:)
    month = occurrence.to_date.beginning_of_month
    month = month.advance(months: @months) until (time = time_in(month)) && time > [occurrence, done_at].max
    time
  end

  private

  def time_in(month)
    date = (month..month.end_of_month).find { @day.call(it) }
    date && at(date)
  end

  def days_from(date)
    (0..SEARCH_DAYS).lazy.map { date + it }.select { @day.call(it) }
  end

  def at(date)
    Reminder::Clock.at(date, @clock)
  end
end
