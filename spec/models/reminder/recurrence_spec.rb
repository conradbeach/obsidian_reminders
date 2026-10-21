require "rails_helper"

RSpec.describe Reminder::Recurrence do
  def recurrence(rule)
    Reminder::Directive.new(rule).recurrence
  end

  describe "#next_time" do
    context "when it repeats on weekdays" do
      it "returns the next scheduled day after both the occurrence and when it was done" do
        run = recurrence("every monday and thursday at 7pm")
        monday = Time.zone.parse("2026-10-19 19:00")

        expect(run.next_time(occurrence: monday, done_at: monday - 1.hour)).to eq(Time.zone.parse("2026-10-22 19:00"))
        expect(run.next_time(occurrence: monday, done_at: monday + 4.days)).to eq(Time.zone.parse("2026-10-26 19:00"))
      end
    end

    context "when it repeats every so many days" do
      it "counts from the day it was done" do
        vitamins = recurrence("every 3 days")
        thursday = Time.zone.parse("2026-10-22 09:00")

        expect(vitamins.next_time(occurrence: thursday, done_at: thursday + 1.day + 13.hours))
          .to eq(Time.zone.parse("2026-10-26 09:00"))
      end
    end

    context "when it repeats every other week" do
      it "comes due two weeks after it was done" do
        monday = Time.zone.parse("2026-10-19 18:00")

        expect(recurrence("every other week at 6pm").next_time(occurrence: monday, done_at: monday + 2.hours))
          .to eq(Time.zone.parse("2026-11-02 18:00"))
      end
    end
  end
end
