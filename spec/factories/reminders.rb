FactoryBot.define do
  factory :reminder do
    note_path { "Tabitha/Errands.md" }
    sequence(:line) { |n| "- [ ] Errand #{n} (@tomorrow 9am)" }
    directive { "tomorrow 9am" }
    remind_at { 1.day.from_now }
  end
end
