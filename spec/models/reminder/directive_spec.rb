require "rails_helper"

# Each row is a directive and when it first goes off, read at a fixed moment: Monday, October 19, 2026, 6pm in
# Mountain time. Daylight saving time ends at 2am on Sunday, November 1. A nil time means the directive isn't
# understood, which is the only safe answer for anything ambiguous: a wrong time goes unnoticed, while an
# unscheduled reminder is listed under "Needs a clearer time".
RSpec.describe Reminder::Directive do
  let(:now) { Time.zone.parse("2026-10-19 18:00") }

  def time_for(text)
    described_class.new(text, now:).time
  end

  def self.reads(form, rows)
    context "when the directive is #{form}" do
      rows.each do |text, expected|
        it "reads “#{text}” as #{expected || 'not understood'}" do
          expect(time_for(text)).to eq(expected && Time.zone.parse(expected))
        end
      end
    end
  end

  describe "#time" do
    reads "a date and a time", [
      ["Oct 21 3:30pm", "2026-10-21 15:30"],
      ["October 21 at 3:30 pm", "2026-10-21 15:30"],
      ["Oct. 21 3:30pm", "2026-10-21 15:30"],
      ["Oct 21, 3:30 PM", "2026-10-21 15:30"],
      ["2026-10-21 15:00", "2026-10-21 15:00"],
      ["10/21/26 7 p.m.", "2026-10-21 19:00"],
      ["21st October, 2027 at noon", "2027-10-21 12:00"],
      ["Dec 3 at 2:00", "2026-12-03 02:00"],
      ["Dec 3 2:00", "2026-12-03 02:00"],
      ["Dec 3 at 14:00", "2026-12-03 14:00"],
      ["at 9am tomorrow", "2026-10-20 09:00"],
      ["tomorrow at 9:15am", "2026-10-20 09:15"],
      ["today 8pm", "2026-10-19 20:00"],
      ["TOMORROW AT 9AM", "2026-10-20 09:00"],
      ["  tomorrow   9am ", "2026-10-20 09:00"],
    ]

    reads "a date, which goes off at 9am", [
      ["tomorrow", "2026-10-20 09:00"],
      ["Oct 21", "2026-10-21 09:00"],
      ["oct 21st", "2026-10-21 09:00"],
      ["21 oct", "2026-10-21 09:00"],
      ["21st of October", "2026-10-21 09:00"],
      ["2026-10-21", "2026-10-21 09:00"],
      ["10/21", "2026-10-21 09:00"],
      ["10/21/2026", "2026-10-21 09:00"],
      ["Oct 19 2027", "2027-10-19 09:00"],
      ["Nov 1", "2026-11-01 09:00"],
    ]

    reads "today, or a date that's today, which keeps its time even once that time has passed", [
      ["today", "2026-10-19 09:00"],
      ["today at 5pm", "2026-10-19 17:00"],
      ["Oct 19", "2026-10-19 09:00"],
    ]

    reads "a month and day that have passed this year, which means next year's", [
      ["Oct 1", "2027-10-01 09:00"],
      ["Jan 5", "2027-01-05 09:00"],
    ]

    reads "a time of day, which is today's or, once it has passed, tomorrow's", [
      ["7pm", "2026-10-19 19:00"],
      ["7 pm", "2026-10-19 19:00"],
      ["7:00 PM", "2026-10-19 19:00"],
      ["7p.m.", "2026-10-19 19:00"],
      ["at 7pm", "2026-10-19 19:00"],
      ["21:00", "2026-10-19 21:00"],
      ["9am", "2026-10-20 09:00"],
      ["6pm", "2026-10-20 18:00"],
      ["noon", "2026-10-20 12:00"],
      ["12am", "2026-10-20 00:00"],
      ["12pm", "2026-10-20 12:00"],
      ["0:30", "2026-10-20 00:30"],
    ]

    reads "a weekday, which is this week's or, once its time has passed, next week's", [
      ["friday", "2026-10-23 09:00"],
      ["fri", "2026-10-23 09:00"],
      ["thurs", "2026-10-22 09:00"],
      ["on friday", "2026-10-23 09:00"],
      ["this friday", "2026-10-23 09:00"],
      ["Friday 5pm", "2026-10-23 17:00"],
      ["tues at 2:30pm", "2026-10-20 14:30"],
      ["monday 7pm", "2026-10-19 19:00"],
      ["monday 5pm", "2026-10-26 17:00"],
      ["monday", "2026-10-26 09:00"],
      ["this monday", "2026-10-26 09:00"],
    ]

    reads "next and a weekday, which skips today's", [
      ["next monday", "2026-10-26 09:00"],
      ["next monday 7pm", "2026-10-26 19:00"],
      ["next friday", "2026-10-23 09:00"],
    ]

    reads "a number of minutes or hours from now", [
      ["in 30 minutes", "2026-10-19 18:30"],
      ["in 30 mins", "2026-10-19 18:30"],
      ["in 90 minutes", "2026-10-19 19:30"],
      ["in an hour", "2026-10-19 19:00"],
      ["in 1 hr", "2026-10-19 19:00"],
      ["in two hours", "2026-10-19 20:00"],
    ]

    reads "a number of days, weeks, months, or years from now", [
      ["in 3 days", "2026-10-22 09:00"],
      ["in a day", "2026-10-20 09:00"],
      ["in two weeks at 10am", "2026-11-02 10:00"],
      ["in 2 weeks 5pm", "2026-11-02 17:00"],
      ["in 1 month", "2026-11-19 09:00"],
      ["in a year", "2027-10-19 09:00"],
    ]

    reads "every so many days, weeks, months, or years, which starts at the next time of day", [
      ["every day", "2026-10-20 09:00"],
      ["every day at 8pm", "2026-10-19 20:00"],
      ["every 3 days", "2026-10-20 09:00"],
      ["every other day", "2026-10-20 09:00"],
      ["every week", "2026-10-20 09:00"],
      ["every two weeks", "2026-10-20 09:00"],
      ["every month", "2026-10-20 09:00"],
      ["every 6 months", "2026-10-20 09:00"],
      ["every year", "2026-10-20 09:00"],
    ]

    reads "every weekday, or a list of weekdays", [
      ["every weekday", "2026-10-20 09:00"],
      ["every weekday at 8pm", "2026-10-19 20:00"],
      ["every weekday at 8:30am", "2026-10-20 08:30"],
      ["every monday", "2026-10-26 09:00"],
      ["every monday at 7pm", "2026-10-19 19:00"],
      ["every monday and thursday at 7pm", "2026-10-19 19:00"],
      ["every mon & thu at 5pm", "2026-10-22 17:00"],
      ["every tue, thu", "2026-10-20 09:00"],
      ["every saturday and sunday", "2026-10-24 09:00"],
    ]

    reads "every few weeks on a weekday", [
      ["every 2 weeks on tuesday at 7:50am", "2026-10-20 07:50"],
      ["every other week on friday", "2026-10-23 09:00"],
      ["every 3 weeks on mon", "2026-10-26 09:00"],
    ]

    reads "every few months on a day of the month", [
      ["every 3 months on the third Sunday", "2026-11-15 09:00"],
      ["every 2 months on the 1st", "2026-11-01 09:00"],
      ["every other month on the last friday at 7pm", "2026-10-30 19:00"],
      ["every 2 months on the 31st", "2026-10-31 09:00"],
      ["every 3 months on the 19th", "2026-11-19 09:00"],
    ]

    reads "a date every year", [
      ["every year on october 1", "2027-10-01 09:00"],
      ["every october 1st", "2027-10-01 09:00"],
      ["every april 19", "2027-04-19 09:00"],
      ["every 1st of september", "2027-09-01 09:00"],
      ["every year on the 25th of december", "2026-12-25 09:00"],
      ["every dec. 25", "2026-12-25 09:00"],
      ["every feb 29", "2028-02-29 09:00"],
      ["every october 19", "2027-10-19 09:00"],
      ["every october 19 at 8pm", "2026-10-19 20:00"],
    ]

    reads "a list of dates every year", [
      ["every sep 1, dec 1, mar 1 and jun 1", "2026-12-01 09:00"],
      ["every September 1st, December 1st, March 1st and June 1st", "2026-12-01 09:00"],
      ["every year on october 1 and april 1", "2027-04-01 09:00"],
    ]

    reads "days of every month", [
      ["every month on the 15th", "2026-11-15 09:00"],
      ["every 15th", "2026-11-15 09:00"],
      ["every 31st", "2026-10-31 09:00"],
      ["every month on the 19th at 8pm", "2026-10-19 20:00"],
      ["every 1st and 15th at 8am", "2026-11-01 08:00"],
      ["every 1st, 15th and 20th", "2026-10-20 09:00"],
    ]

    reads "an nth weekday of every month", [
      ["every first monday", "2026-11-02 09:00"],
      ["every 2nd tue at 7pm", "2026-11-10 19:00"],
      ["every 5th friday", "2026-10-30 09:00"],
      ["every fifth friday", "2026-10-30 09:00"],
      ["every 2nd and 4th monday", "2026-10-26 09:00"],
      ["every first and last friday", "2026-10-30 09:00"],
    ]

    reads "an nth weekday of certain months", [
      ["every last saturday in october", "2026-10-31 09:00"],
      ["every 3rd Sat of Sep", "2027-09-18 09:00"],
      ["every 1st & 3rd tue in may", "2027-05-04 09:00"],
      ["every 3rd Saturday in January, March, June, August, November", "2026-11-21 09:00"],
      ["every last fri of oct and dec", "2026-10-30 09:00"],
      ["every first Monday in March, June, September and December", "2026-12-07 09:00"],
    ]

    reads "calendar repeats joined with “and”", [
      ["every 2nd Saturday in November and 2nd Saturday in May", "2026-11-14 09:00"],
      ["every last friday & 15th", "2026-10-30 09:00"],
    ]

    reads "a repeat with a starting date, which is its first occurrence, even if it's past or off the schedule", [
      ["every 6 months from 2027-03-01", "2027-03-01 09:00"],
      ["every year from march 1", "2027-03-01 09:00"],
      ["every 2nd sun from 2026-10-25", "2026-10-25 09:00"],
      ["every 2 weeks on tue at 7:50am from 2026-10-13", "2026-10-13 07:50"],
      ["every day at 7:30am from 2026-11-02", "2026-11-02 07:30"],
      ["every day from Tuesday", "2026-10-20 09:00"],
      ["every day starting friday", "2026-10-23 09:00"],
      ["every day from next monday at 8am", "2026-10-26 08:00"],
      ["every day at 8am from next monday", "2026-10-26 08:00"],
      ["every day at 7am from friday at 9pm", "2026-10-23 07:00"],
    ]

    reads "something that isn't a time", [
      ["", nil],
      ["whenever", nil],
      ["next week", nil],
      ["monday morning", nil],
      ["9", nil],
      ["tomorrow 9", nil],
      ["tu", nil],
      ["Dec at 2:00", nil],
    ]

    reads "a time or date that doesn't exist", [
      ["13pm", nil],
      ["25:00", nil],
      ["7:60pm", nil],
      ["Feb 30", nil],
      ["Oct 32", nil],
      ["13/01", nil],
    ]

    reads "a repeat that isn't understood", [
      ["every", nil],
      ["every blue moon", nil],
      ["every 0 days", nil],
      ["every monday and sometimes", nil],
      ["every weekend", nil],
      ["every feb 30", nil],
      ["every 32nd", nil],
      ["every 6th monday", nil],
      ["every 2 months on monday", nil],
      ["every day from whenever", nil],
    ]
  end
end
