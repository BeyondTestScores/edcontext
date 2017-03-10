require 'twilio-ruby'

class Attempt < ApplicationRecord

  belongs_to :schedule
  belongs_to :recipient
  belongs_to :recipient_schedule
  belongs_to :question

  def send_message
    twilio_number = ENV['TWILIO_NUMBER']
    client = Twilio::REST::Client.new ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN']

    message = client.messages.create(
      from: twilio_number,
      to:   recipient.phone,
      body: "#{question.text}%0a%0a#{question.option1}: Reply 1\n\r%0a%Oa#{question.option2}: Reply 2%0a#{question.option3}: Reply 3%0a#{question.option4}: Reply 4%0a#{question.option5}: Reply 5"
    )

    puts message.inspect
    puts message.try(:path)
    puts message.try(:sid)
    # message.path.split('/').last

    update_attributes(sent_at: Time.new, twilio_sid: message.sid)
  end

end
