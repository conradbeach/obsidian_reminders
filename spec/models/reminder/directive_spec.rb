require "rails_helper"

RSpec.describe Reminder::Directive do
  # A Monday evening in Mountain time.
  let(:now) { Time.zone.parse("2026-10-19 18:00") }

  def time_for(text)
    described_class.new(text, now:).time
  end

  describe "#time" do
    context "when the directive has a date and a time" do
      it "returns that date and time, in any common format and order" do
        expect(time_for("Oct 21 3:30pm")).to eq(Time.zone.parse("2026-10-21 15:30"))
        expect(time_for("2026-10-21 15:00")).to eq(Time.zone.parse("2026-10-21 15:00"))
        expect(time_for("10/21/26 7 p.m.")).to eq(Time.zone.parse("2026-10-21 19:00"))
        expect(time_for("21st October, 2027 at noon")).to eq(Time.zone.parse("2027-10-21 12:00"))
        expect(time_for("at 9am tomorrow")).to eq(Time.zone.parse("2026-10-20 09:00"))
      end
    end

    context "when the directive has only a date" do
      it "returns 9am on that date" do
        expect(time_for("tomorrow")).to eq(Time.zone.parse("2026-10-20 09:00"))
        expect(time_for("Oct 21")).to eq(Time.zone.parse("2026-10-21 09:00"))
      end
    end

    context "when the date is the day daylight saving time ends" do
      it "returns 9am on that date" do
        expect(time_for("Nov 1")).to eq(Time.zone.parse("2026-11-01 09:00"))
      end
    end

    context "when a month and day have already passed this year" do
      it "returns that date next year" do
        expect(time_for("Oct 1")).to eq(Time.zone.parse("2027-10-01 09:00"))
      end
    end

    context "when the directive has only a time" do
      it "returns that time today, or tomorrow once it has passed" do
        expect(time_for("7pm")).to eq(Time.zone.parse("2026-10-19 19:00"))
        expect(time_for("21:00")).to eq(Time.zone.parse("2026-10-19 21:00"))
        expect(time_for("9am")).to eq(Time.zone.parse("2026-10-20 09:00"))
      end
    end

    context "when the directive is a weekday" do
      it "returns its next occurrence, moving to next week once its time has passed today" do
        expect(time_for("friday")).to eq(Time.zone.parse("2026-10-23 09:00"))
        expect(time_for("tues at 2:30pm")).to eq(Time.zone.parse("2026-10-20 14:30"))
        expect(time_for("monday 7pm")).to eq(Time.zone.parse("2026-10-19 19:00"))
        expect(time_for("monday 5pm")).to eq(Time.zone.parse("2026-10-26 17:00"))
      end
    end

    context "when the directive is next and today's weekday" do
      it "returns next week's" do
        expect(time_for("next monday 7pm")).to eq(Time.zone.parse("2026-10-26 19:00"))
      end
    end

    context "when the directive is a number of minutes or hours from now" do
      it "returns that long from now" do
        expect(time_for("in 30 minutes")).to eq(Time.zone.parse("2026-10-19 18:30"))
        expect(time_for("in an hour")).to eq(Time.zone.parse("2026-10-19 19:00"))
      end
    end

    context "when the directive is a number of days, weeks, or months from now" do
      it "returns that date, at 9am unless a time is given" do
        expect(time_for("in 3 days")).to eq(Time.zone.parse("2026-10-22 09:00"))
        expect(time_for("in two weeks at 10am")).to eq(Time.zone.parse("2026-11-02 10:00"))
        expect(time_for("in 1 month")).to eq(Time.zone.parse("2026-11-19 09:00"))
      end
    end

    context "when the directive repeats" do
      it "returns the first occurrence that hasn't passed" do
        expect(time_for("every 3 days")).to eq(Time.zone.parse("2026-10-20 09:00"))
        expect(time_for("every monday and thursday at 7pm")).to eq(Time.zone.parse("2026-10-19 19:00"))
        expect(time_for("every mon & thu at 5pm")).to eq(Time.zone.parse("2026-10-22 17:00"))
        expect(time_for("every weekday at 8:30am")).to eq(Time.zone.parse("2026-10-20 08:30"))
      end
    end

    context "when a repeating directive is fixed to the calendar" do
      it "returns its first scheduled date" do
        expect(time_for("every year on october 1")).to eq(Time.zone.parse("2027-10-01 09:00"))
        expect(time_for("every last saturday in october")).to eq(Time.zone.parse("2026-10-31 09:00"))
        expect(time_for("every 3rd Sat of Sep")).to eq(Time.zone.parse("2027-09-18 09:00"))
        expect(time_for("every 2nd tue at 7pm")).to eq(Time.zone.parse("2026-11-10 19:00"))
        expect(time_for("every month on the 15th")).to eq(Time.zone.parse("2026-11-15 09:00"))
      end
    end

    context "when a repeating directive joins calendar rules with \"and\"" do
      it "returns the next date any of them schedules" do
        expect(time_for("every 2nd Saturday in November and 2nd Saturday in May"))
          .to eq(Time.zone.parse("2026-11-14 09:00"))
        expect(time_for("every 1st and 15th at 8am")).to eq(Time.zone.parse("2026-11-01 08:00"))
        expect(time_for("every 1st, 15th and 20th")).to eq(Time.zone.parse("2026-10-20 09:00"))
      end
    end

    context "when a repeating directive names an nth weekday in several months" do
      it "returns that weekday in the next of those months" do
        expect(time_for("every 3rd Saturday in January, March, June, August, November"))
          .to eq(Time.zone.parse("2026-11-21 09:00"))
        expect(time_for("every last fri of oct and dec")).to eq(Time.zone.parse("2026-10-30 09:00"))
      end
    end

    context "when a repeating directive is every few months on a day of the month" do
      it "returns the next such day" do
        expect(time_for("every 3 months on the third Sunday")).to eq(Time.zone.parse("2026-11-15 09:00"))
        expect(time_for("every 2 months on the 1st")).to eq(Time.zone.parse("2026-11-01 09:00"))
      end
    end

    context "when a repeating directive lists dates each year" do
      it "returns the next of those dates" do
        expect(time_for("every 1st of september")).to eq(Time.zone.parse("2027-09-01 09:00"))
        expect(time_for("every September 1st, December 1st, March 1st and June 1st"))
          .to eq(Time.zone.parse("2026-12-01 09:00"))
      end
    end

    context "when a repeating directive has a starting date" do
      it "returns that date, even if it's past or off the schedule" do
        expect(time_for("every 2nd sun from 2026-10-25")).to eq(Time.zone.parse("2026-10-25 09:00"))
        expect(time_for("every 6 months from 2027-03-01")).to eq(Time.zone.parse("2027-03-01 09:00"))
        expect(time_for("every 2 weeks on tue at 7:50am from 2026-10-13"))
          .to eq(Time.zone.parse("2026-10-13 07:50"))
      end
    end

    context "when a repeating directive's starting date is a weekday followed by a time" do
      it "starts on that weekday at that time" do
        expect(time_for("every day from Tuesday")).to eq(Time.zone.parse("2026-10-20 09:00"))
        expect(time_for("every day from next monday at 8am")).to eq(Time.zone.parse("2026-10-26 08:00"))
      end
    end

    context "when a repeating directive isn't recognized" do
      it "returns nil" do
        expect(time_for("every blue moon")).to be_nil
        expect(time_for("every 0 days")).to be_nil
        expect(time_for("every monday and sometimes")).to be_nil
      end
    end

    context "when the directive isn't a recognized date or time" do
      it "returns nil rather than guessing" do
        expect(time_for("whenever")).to be_nil
        expect(time_for("next week")).to be_nil
        expect(time_for("9")).to be_nil
        expect(time_for("13pm")).to be_nil
        expect(time_for("Feb 30")).to be_nil
      end
    end
  end
end
