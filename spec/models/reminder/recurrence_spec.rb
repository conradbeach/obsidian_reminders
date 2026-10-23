require "rails_helper"

# Each row is a repeating directive, the occurrence being marked done, when it was marked done, and when the reminder
# comes due next, in Mountain time. Intervals count from the day an occurrence was done; every other kind keeps to
# its schedule, moving to the first scheduled time after both the occurrence and when it was done. A nil next time
# means none could be found.
RSpec.describe Reminder::Recurrence do
  def self.moves(form, rows)
    context "when it repeats #{form}" do
      rows.each do |rule, occurrence, done_at, expected|
        it "moves “#{rule}” due #{occurrence} and done #{done_at} to #{expected || 'nothing'}" do
          recurrence = Reminder::Directive.new(rule).recurrence

          next_time = recurrence.next_time(occurrence: Time.zone.parse(occurrence), done_at: Time.zone.parse(done_at))

          expect(next_time).to eq(expected && Time.zone.parse(expected))
        end
      end
    end
  end

  describe "#next_time" do
    moves "every so many days, weeks, months, or years, counting from the day it was done", [
      ["every 3 days", "2026-10-22 09:00", "2026-10-22 09:30", "2026-10-25 09:00"],
      ["every 3 days", "2026-10-22 09:00", "2026-10-23 22:00", "2026-10-26 09:00"],
      ["every 3 days", "2026-10-22 09:00", "2026-10-21 20:00", "2026-10-24 09:00"],
      ["every day at 8pm", "2026-10-19 20:00", "2026-10-19 20:05", "2026-10-20 20:00"],
      ["every day at 8am", "2026-10-20 08:00", "2026-10-20 07:00", "2026-10-21 08:00"],
      ["every day", "2026-10-31 09:00", "2026-10-31 09:10", "2026-11-01 09:00"],
      ["every other day", "2026-10-20 09:00", "2026-10-20 12:00", "2026-10-22 09:00"],
      ["every week", "2026-10-20 09:00", "2026-10-20 10:00", "2026-10-27 09:00"],
      ["every 2 weeks", "2026-10-20 09:00", "2026-10-22 10:00", "2026-11-05 09:00"],
      ["every month", "2027-01-31 09:00", "2027-01-31 10:00", "2027-02-28 09:00"],
      ["every 6 months", "2026-10-20 09:00", "2026-10-25 10:00", "2027-04-25 09:00"],
      ["every year", "2028-02-29 09:00", "2028-02-29 10:00", "2029-02-28 09:00"],
      ["every 6 months from 2027-03-01", "2027-03-01 09:00", "2027-03-04 10:00", "2027-09-04 09:00"],
    ]

    moves "on weekdays", [
      ["every monday and thursday at 7pm", "2026-10-19 19:00", "2026-10-19 18:00", "2026-10-22 19:00"],
      ["every monday and thursday at 7pm", "2026-10-19 19:00", "2026-10-23 08:00", "2026-10-26 19:00"],
      ["every weekday", "2026-10-23 09:00", "2026-10-23 09:30", "2026-10-26 09:00"],
      ["every monday", "2026-10-19 09:00", "2026-11-04 12:00", "2026-11-09 09:00"],
      ["every sunday at 9am", "2026-10-25 09:00", "2026-10-25 09:30", "2026-11-01 09:00"],
    ]

    moves "every few weeks on a weekday, keeping to its schedule", [
      ["every 2 weeks on tuesday at 7:50am", "2026-10-20 07:50", "2026-10-20 08:00", "2026-11-03 07:50"],
      ["every 2 weeks on tuesday at 7:50am", "2026-10-20 07:50", "2026-10-19 21:00", "2026-11-03 07:50"],
      ["every 2 weeks on tuesday at 7:50am", "2026-10-20 07:50", "2026-10-29 12:00", "2026-11-03 07:50"],
      ["every 2 weeks on tuesday at 7:50am", "2026-10-20 07:50", "2026-11-05 12:00", "2026-11-17 07:50"],
      ["every other week on friday", "2026-10-23 09:00", "2026-10-23 10:00", "2026-11-06 09:00"],
    ]

    moves "every few months on a day of the month, keeping to its schedule", [
      ["every 3 months on the third Sunday", "2026-11-15 09:00", "2026-11-16 09:00", "2027-02-21 09:00"],
      ["every 3 months on the third Sunday", "2026-11-15 09:00", "2027-03-15 09:00", "2027-05-16 09:00"],
      ["every 2 months on the 1st", "2026-11-01 09:00", "2026-11-01 09:30", "2027-01-01 09:00"],
      ["every other month on the last friday at 7pm", "2026-10-30 19:00", "2026-10-30 19:30", "2026-12-25 19:00"],
      ["every 3 months on the 31st", "2027-01-31 09:00", "2027-01-31 09:30", "2027-07-31 09:00"],
      ["every 12 months on the 31st from 2027-02-10", "2027-02-10 09:00", "2027-02-10 09:30", nil],
    ]

    moves "on dates every year", [
      ["every year on the last saturday in october", "2026-10-31 09:00", "2026-10-31 20:00", "2027-10-30 09:00"],
      ["every october 1", "2026-10-01 09:00", "2026-10-09 12:00", "2027-10-01 09:00"],
      ["every feb 29", "2028-02-29 09:00", "2028-02-29 10:00", "2032-02-29 09:00"],
      ["every sep 1, dec 1, mar 1 and jun 1", "2026-12-01 09:00", "2026-12-05 09:00", "2027-03-01 09:00"],
      ["every sep 1, dec 1, mar 1 and jun 1", "2027-06-01 09:00", "2027-06-01 09:30", "2027-09-01 09:00"],
    ]

    moves "on days of every month", [
      ["every 1st and 15th", "2026-11-01 09:00", "2026-11-01 09:30", "2026-11-15 09:00"],
      ["every 1st and 15th", "2026-11-01 09:00", "2026-11-20 09:00", "2026-12-01 09:00"],
      ["every 31st", "2026-10-31 09:00", "2026-10-31 09:30", "2026-12-31 09:00"],
    ]

    moves "on nth weekdays", [
      ["every 2nd and 4th monday at 7pm", "2026-10-26 19:00", "2026-10-26 19:30", "2026-11-09 19:00"],
      ["every 5th friday", "2026-10-30 09:00", "2026-10-30 09:30", "2027-01-29 09:00"],
      ["every 2nd Saturday in November and 2nd Saturday in May", "2026-11-14 09:00", "2026-11-14 11:00",
       "2027-05-08 09:00"],
      ["every 3rd Saturday in January, March, June, August and November", "2026-11-21 09:00", "2026-11-21 10:00",
       "2027-01-16 09:00"],
      ["every first Monday in March, June, September and December", "2026-12-07 09:00", "2026-12-07 10:00",
       "2027-03-01 09:00"],
    ]
  end
end
