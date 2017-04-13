require 'rails_helper'

describe "survey:attempt_questions" do
  include_context "rake"

  it 'should have environment as a prerequisite' do
    expect(subject.prerequisites).to include("environment")
  end

  describe "basic flow" do
    let(:ready_recipient_schedule)    { double('ready recipient schedule', attempt_question: nil) }
    let(:recipient_schedules)         { double("recipient schedules", ready: [ready_recipient_schedule]) }
    let(:active_schedule)             { double("active schedule", recipient_schedules: recipient_schedules) }

    it "finds all active schedules" do
      expect(ready_recipient_schedule).to receive(:attempt_question)
      expect(active_schedule).to receive(:recipient_schedules)
      expect(Schedule).to receive(:active).and_return([active_schedule])
      subject.invoke
    end
  end

  describe "complex flow" do

    let!(:school) { School.create!(name: 'School') }

    let!(:recipients) { create_recipients(school, 3) }
    let!(:recipient_list) do
      school.recipient_lists.create!(name: 'Parents', recipient_ids: recipients.map(&:id).join(','))
    end

    let!(:category) { Category.create(name: 'Category') }
    let!(:questions) { create_questions(3, category) }
    let!(:question_list) do
      QuestionList.create!(name: 'Parent Questions', question_ids: questions.map(&:id).join(','))
    end

    let!(:schedule) do
      Schedule.create!(
        name: 'Parent Schedule',
        recipient_list_id: recipient_list.id,
        question_list: question_list,
        frequency_hours: 24 * 7,
        start_date: Time.new,
        end_date: 1.year.from_now,
        time: 1200
      )
    end

    describe 'First attempt not at specified time' do
      before :each do
        now = DateTime.now
        date = ActiveSupport::TimeZone["America/New_York"].parse(now.strftime("%Y-%m-%dT19:00:00%z"))
        Timecop.freeze(date) { subject.invoke }
      end

      it 'should not create any attempts' do
        expect(Attempt.count).to eq(0)
      end
    end


    describe 'First attempt at specified time' do

      before :each do
        now = DateTime.now
        date = ActiveSupport::TimeZone["America/New_York"].parse(now.strftime("%Y-%m-%dT20:00:00%z"))
        Timecop.freeze(date) { subject.invoke }
      end

      it 'should create the first attempt for each recipient' do
        recipients.each do |recipient|
          recipient.reload
          expect(recipient.attempts.count).to eq(1)
          attempt = recipient.attempts.first
          expect(attempt.sent_at).to be_present
          expect(attempt.answer_index).to be_nil
        end
      end
    end

    describe 'Second Attempts' do
      before :each do
        recipients.each do |recipient|
          recipient_schedule = schedule.recipient_schedules.for(recipient).first
          recipient_schedule.attempt_question
        end
      end

      describe 'Immediate' do
        before :each do
          subject.invoke
        end

        it 'should do nothing' do
          recipients.each do |recipient|
            recipient.reload
            expect(recipient.attempts.count).to eq(1)
          end
        end
      end

      describe 'A Week Later' do
        before :each do
          Timecop.freeze(Date.today + 10) { subject.invoke }
        end

        it 'should create the second attempt for each recipient with a different question' do
          recipients.each do |recipient|
            recipient.reload
            expect(recipient.attempts.count).to eq(2)
            attempt = recipient.attempts.last
            expect(attempt.sent_at).to be_present
            expect(attempt.answer_index).to be_nil

            first_attempt = recipient.attempts.first
            expect(first_attempt.question).to_not eq(attempt.question)
          end
        end
      end
    end

    describe 'Opted Out Recipient' do

      before :each do
        recipients[1].update_attributes(opted_out: true)
        Timecop.freeze
        subject.invoke
      end

      it 'should create the first attempt for each recipient' do
        recipients.each_with_index do |recipient, index|
          recipient.reload
          if index == 1
            expect(recipient.attempts.count).to eq(0)
            expect(recipient.attempts.first).to be_nil
          else
            expect(recipient.attempts.count).to eq(1)
            attempt = recipient.attempts.first
            expect(attempt.sent_at).to be_present
            expect(attempt.answer_index).to be_nil
          end
        end
      end
    end

  end
end
