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
      it "returns 8am on that date" do
        expect(time_for("tomorrow")).to eq(Time.zone.parse("2026-10-20 08:00"))
        expect(time_for("Oct 21")).to eq(Time.zone.parse("2026-10-21 08:00"))
      end
    end

    context "when the date is the day daylight saving time ends" do
      it "returns 8am on that date" do
        expect(time_for("Nov 1")).to eq(Time.zone.parse("2026-11-01 08:00"))
      end
    end

    context "when a month and day have already passed this year" do
      it "returns that date next year" do
        expect(time_for("Oct 1")).to eq(Time.zone.parse("2027-10-01 08:00"))
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
        expect(time_for("friday")).to eq(Time.zone.parse("2026-10-23 08:00"))
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
      it "returns that date, at 8am unless a time is given" do
        expect(time_for("in 3 days")).to eq(Time.zone.parse("2026-10-22 08:00"))
        expect(time_for("in two weeks at 10am")).to eq(Time.zone.parse("2026-11-02 10:00"))
        expect(time_for("in 1 month")).to eq(Time.zone.parse("2026-11-19 08:00"))
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
