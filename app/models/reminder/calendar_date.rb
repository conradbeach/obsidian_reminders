# A date written out in a directive: "2026-10-21", "10/21/26", "Oct 21", "21st of October 2027". Without a year, it's
# the date's next occurrence, which for February 29th can be years away.
module Reminder::CalendarDate
  FORMATS = [
    /\A(?<year>\d{4})-(?<month>\d{1,2})-(?<day>\d{1,2})\z/,
    %r{\A(?<month>\d{1,2})/(?<day>\d{1,2})(?:/(?<year>\d{4}|\d{2}))?\z},
    /\A(?<month>[a-z]{3,})\.?\s+(?<day>\d{1,2})(?:st|nd|rd|th)?(?:\s+(?<year>\d{4}))?\z/,
    /\A(?<day>\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(?<month>[a-z]{3,})\.?(?:\s+(?<year>\d{4}))?\z/,
  ].freeze
  # Far enough ahead to find the next February 29th.
  SEARCH_YEARS = 8

  def self.parse(text, today:)
    match = FORMATS.lazy.filter_map { it.match(text) }.first or return
    month = month(match[:month]) or return
    match[:year] ? date(year(match[:year]), month, match[:day].to_i) : next_date(today, month, match[:day].to_i)
  end

  def self.next_date(today, month, day)
    (today.year..(today.year + SEARCH_YEARS)).lazy.filter_map { date(it, month, day) }.find { it >= today }
  end

  def self.date(year, month, day)
    Date.new(year, month, day) if Date.valid_date?(year, month, day)
  end

  def self.year(text)
    text.length == 2 ? 2000 + text.to_i : text.to_i
  end

  def self.month(text)
    Integer(text, 10, exception: false) || Reminder::Directive::MONTHS.index { it.start_with?(text) }&.succ
  end
  private_class_method :next_date, :date, :year, :month
end
