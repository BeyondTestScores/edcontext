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

  def survey_monkey_pages_structure
    pages = {}
    questions.each_with_index do |question, index|
      pages[question.category.name] ||= {title: question.category.name, questions: []}
      pages[question.category.name][:questions] << {
        "family": "single_choice",
        "subtype": "vertical",
        "answers": {
          "choices": [
            {
              "text": question.option1,
              "position": 1
            },
            {
              "text": question.option2,
              "position": 2
            },
            {
              "text": question.option3,
              "position": 3
            },
            {
              "text": question.option4,
              "position": 4
            },
            {
              "text": question.option5,
              "position": 5
            }
          ]
        },
        "headings": [
          {
            "heading": question.text
          }
        ],
        "position": index
      }
    end
    return pages
  end

  def create_survey_monkey_survey
    return if survey_monkey_id.present?

    response = surveyMonkeyConnection.post('surveys', {
      "title":"#{name}",
      "pages": survey_monkey_pages_structure.values
    }.to_json)

    update(survey_monkey_id: response.body['id'])
  end

  def survey_monkey_details
    return if survey_monkey_id.blank?
    surveyMonkeyConnection.get("surveys/#{survey_monkey_id}/details").body
  end

  def survey_monkey_pages
    return if survey_monkey_id.blank?
    surveyMonkeyConnection.get("surveys/#{survey_monkey_id}/pages").body
  end

  def update_survey_monkey(updates)
    return if survey_monkey_id.blank?
    surveyMonkeyConnection.patch("surveys/#{survey_monkey_id}", updates.to_json)
  end

  # def create_survey_monkey_question(question)
  #   pages = survey_monkey_pages
  #   response = surveyMonkeyConnection.post("surveys/#{survey_monkey_id}")
  # end
  #
  # def update_survey_monkey_question(question)
  # end
  #
  # def remove_survey_monkey_question(question)
  # end

  def sync_with_survey_monkey
    details = survey_monkey_details
    # pages = survey_monkey_pages
    if name != details['title']
      update_survey_monkey({
        "title": name
      })
    end
  end

end
