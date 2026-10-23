# A repeating directive ("every monday at 7pm"), with an optional start ("from oct 26"), end ("until friday", "from
# monday to friday"), or length ("for 2 weeks"). Relative dates are read from now, except an end that follows a
# start, which is read from the start: "from monday to friday" is that Monday and the Friday after it. "every year
# from september 1 to september 7" is a window of days every year rather than a start and an end.
class Reminder::Directive::Repeat
  LENGTH = /\s+for\s+(?<count>\d+|[a-z]+)\s+(?<unit>day|week|month|year)s?\z/

  def initialize(text, now:, starts_on: nil)
    @now = now
    @starts_on = starts_on
    @length = LENGTH.match(text)
    text = @length.pre_match if @length
    text, @end_text = text.split(/\s+until\s+/, 2)
    @rule_text, @start_text = text.split(/\s+(?:from|starting)\s+/, 2)
    @start_text, @end_text = @start_text.split(/\s+to\s+/, 2) if @start_text && !@end_text
  end

  # Nil if any part of the directive isn't understood.
  def recurrence
    return @recurrence if defined?(@recurrence)

    @recurrence = (build if understood?)
  end

  def first_time
    recurrence&.first_time(@now)
  end

  # The last day it repeats on, or nil if it doesn't end. A length counts from the first occurrence: "every day for
  # 1 week" is seven days of reminders.
  def ends_on
    return unless recurrence && !yearly_window?

    if @length then first_time.advance("#{@length[:unit]}s": length_count).to_date - 1
    elsif @end_text then end_date
    end
  end

  private

  def understood?
    (!@start_text || start_date) && (!@end_text || end_date) && (!@length || length_count&.positive?)
  end

  def build
    rule, clock = Reminder::Clock.split(@rule_text)
    clock ||= start_clock || end_clock || [Reminder::Directive::DATE_ONLY_HOUR, 0]
    return yearly_window(clock) if yearly_window?

    Reminder::Recurrence.parse(rule, clock, anchor: start_date || @starts_on)
  end

  def yearly_window?
    Reminder::Clock.split(@rule_text).first == "every year" && @start_text && @end_text && !@length
  end

  # Every day from the start's month and day through the end's, each year, wrapping past New Year if need be.
  def yearly_window(clock)
    from, to = [start_date, end_date].map { day_of_year(it) }
    rule = lambda do |date|
      day = day_of_year(date)
      from <= to ? day.between?(from, to) : day >= from || day <= to
    end
    Reminder::Recurrence::Calendar.new(clock:, anchor: nil, rule:)
  end

  # A month and day as a number that sorts like the calendar: 901 for September 1st.
  def day_of_year(date)
    (date.month * 100) + date.day
  end

  def start_date
    @start_date ||= @start_text && date_in(@start_text, from: @now)
  end

  def end_date
    @end_date ||= @end_text && date_in(@end_text, from: start_date&.in_time_zone || @now)
  end

  def start_clock
    @start_text && Reminder::Clock.split(@start_text).last
  end

  def end_clock
    @end_text && Reminder::Clock.split(@end_text).last
  end

  def date_in(text, from:)
    Reminder::Directive.new(Reminder::Clock.split(text).first, now: from).time&.to_date
  end

  def length_count
    Reminder::Directive.count(@length[:count])
  end
end
