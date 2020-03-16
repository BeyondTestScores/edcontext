class Survey < ApplicationRecord

  has_many :survey_questions
  has_many :questions, through: :survey_questions

  validates :name, presence: true, length: { minimum: 1 }

  after_create :create_survey_monkey_survey

  after_commit :sync_with_survey_monkey

  def to_s
    name
  end

  def has_question(question)
    questions.include?(question)
  end

  def category_tree
    tree = {child_categories: []}

    questions.each do |question|
        category = question.category
        question_path = []
        while category
          question_path << category
          category = category.parent_category
        end

        node = tree
        question_path.reverse.each do |category|
          category_hash = node[:child_categories].find { |cc| cc[:category].name == category.name }
          if category_hash.blank?
            category_hash = {category: category, child_categories: []}
            node[:child_categories].push(category_hash)
          end
          node[:child_categories].sort! { |a,b| a[:category].name <=> b[:category].name }
          node = category_hash
        end

        node[:questions] ||= []
        node[:questions] << question
    end

    return tree
  end

  def surveyMonkeyConnection
    Faraday.new('https://api.surveymonkey.com/v3') do |conn|
      conn.adapter Faraday.default_adapter
      conn.response :json, :content_type => /\bjson$/
      conn.headers['Authorization'] = "bearer #{Rails.application.credentials.dig(:surveymonkey)[:access_token]}"
      conn.headers['Content-Type'] = 'application/json'
    end
  end

  def create_survey_monkey_survey
    return if survey_monkey_id.present?
    response = surveyMonkeyConnection.post('surveys', {"title":"#{name}"}.to_json)
    update(survey_monkey_id: response.body['id'])
  end

  def survey_monkey_details
    surveyMonkeyConnection.get("surveys/#{survey_monkey_id}/details").body
  end

  def survey_monkey_pages
    surveyMonkeyConnection.get("surveys/#{survey_monkey_id}/pages").body
  end

  def update_survey_monkey(updates)
    surveyMonkeyConnection.patch("surveys/#{survey_monkey_id}", updates.to_json)
  end

  def sync_with_survey_monkey
    details = survey_monkey_details
    pages = survey_monkey_pages
    if name != details['title']
      update_survey_monkey(title: name)
    end
  end

end
