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

    context "when it repeats every so many months" do
      it "counts from the day it was done" do
        filter = recurrence("every 6 months")

        expect(filter.next_time(occurrence: Time.zone.parse("2026-10-01 09:00"),
          done_at: Time.zone.parse("2026-10-19 20:00")))
          .to eq(Time.zone.parse("2027-04-19 09:00"))
      end
    end

    context "when it repeats every few weeks on a weekday" do
      it "keeps to the schedule however late it was done" do
        trash = recurrence("every 2 weeks on tuesday at 7:50am")
        tuesday = Time.zone.parse("2026-10-13 07:50")

        expect(trash.next_time(occurrence: tuesday,
          done_at: tuesday + 1.hour)).to eq(Time.zone.parse("2026-10-27 07:50"))
        expect(trash.next_time(occurrence: tuesday,
          done_at: tuesday + 16.days)).to eq(Time.zone.parse("2026-11-10 07:50"))
      end
    end

    context "when it's fixed to the calendar" do
      it "returns the next scheduled date" do
        halloween_party = recurrence("every year on the last saturday in october")

        expect(halloween_party.next_time(occurrence: Time.zone.parse("2026-10-31 09:00"),
          done_at: Time.zone.parse("2026-10-31 20:00"))).to eq(Time.zone.parse("2027-10-30 09:00"))
      end

      it "moves through a list of dates each year, whenever each is done" do
        quarterly = recurrence("every September 1st, December 1st, March 1st and June 1st")
        december = Time.zone.parse("2026-12-01 09:00")

        expect(quarterly.next_time(occurrence: december, done_at: december + 4.days))
          .to eq(Time.zone.parse("2027-03-01 09:00"))
        expect(quarterly.next_time(occurrence: Time.zone.parse("2027-06-01 09:00"), done_at: december + 6.months))
          .to eq(Time.zone.parse("2027-09-01 09:00"))
      end
    end
  end
end
