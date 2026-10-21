# How a repeating reminder repeats, from the "every ..." in its directive. Each kind answers when its first occurrence
# is and, once an occurrence is marked done, when the next one is.
module Reminder::Recurrence
  # nil if the rule isn't one we recognize. The anchor, from "... from <date>", is the date of the first occurrence.
  def self.parse(rule, clock, anchor: nil)
    body = rule.delete_prefix("every").strip
    [Interval, WeeklyInterval, Calendar].lazy.filter_map { it.parse(body, clock:, anchor:) }.first
  end

  def self.count(text)
    text == "other" ? 2 : Reminder::Directive.count(text || "1")
  end

  def self.weekday(name)
    Reminder::Directive::WEEKDAYS.index { it.start_with?(name) } if name.length >= 3
  end

  def self.month(name)
    Reminder::Directive::MONTHS.index { it.start_with?(name) }&.succ if name.length >= 3
  end
end
