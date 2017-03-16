require 'csv'

namespace :data do
  desc "Load in all data"
  task load: :environment do
    return if School.count > 0
    Rake::Task["db:seed"].invoke
    Rake::Task["data:load_categories"].invoke
    Rake::Task["data:load_questions"].invoke
    Rake::Task["data:load_student_responses"].invoke
  end

  desc 'Load in category data'
  task load_categories: :environment do
    measures = JSON.parse(File.read(File.expand_path('../../../data/measures.json', __FILE__)))
    measures.each_with_index do |measure, index|
      category = Category.create(
        name: measure['title'],
        blurb: measure['blurb'],
        description: measure['text'],
        external_id: index + 1
      )

      measure['sub'].keys.sort.each do |key|
        subinfo = measure['sub'][key]
        subcategory = category.child_categories.create(
          name: subinfo['title'],
          blurb: subinfo['blurb'],
          description: subinfo['text'],
          external_id: key
        )

        subinfo['measures'].keys.sort.each do |subinfo_key|
          subsubinfo = subinfo['measures'][subinfo_key]
          subsubcategory = subcategory.child_categories.create(
            name: subsubinfo['title'],
            blurb: subsubinfo['blurb'],
            description: subsubinfo['text'],
            external_id: subinfo_key
          )

          # if subsubinfo['nonlikert'].present?
          #   subsubinfo['nonlikert'].each do |nonlikert_info|
          #     next unless nonlikert_info['likert'].present?
          #     nonlikert = subsubcategory.child_measures.create(
          #       name: nonlikert_info['title'],
          #       description: nonlikert_info['benchmark_explanation'],
          #       benchmark: nonlikert_info['benchmark']
          #     )
          #
          #    name_map = {
          #       "argenziano": "dr-albert-f-argenziano-school-at-lincoln-park",
          #       "healey": "arthur-d-healey-school",
          #       "brown": "benjamin-g-brown-school",
          #       "east": "east-somerville-community-school",
          #       "kennedy": "john-f-kennedy-elementary-school",
          #       "somervillehigh": "somerville-high-school",
          #       "west": "west-somerville-neighborhood-school",
          #       "winter": "winter-hill-community-innovation-school"
          #     }
          #
          #     nonlikert_info['likert'].each do |key, likert|
          #       school_name = name_map[key.to_sym]
          #       next if school_name.nil?
          #       school = School.friendly.find(school_name)
          #       nonlikert.measurements.create(school: school, likert: likert, nonlikert: nonlikert_info['values'][key])
          #     end
          #   end
          # end
        end
      end
    end
  end

  desc 'Load in question data'
  task load_questions: :environment do
    variations = [
      'homeroom',
      'English',
      'Math',
      'Science',
      'Social Studies'
    ]

    questions = JSON.parse(File.read(File.expand_path('../../../data/questions.json', __FILE__)))
    questions.each do |question|
      category = nil
      question['category'].split('-').each do |external_id|
        categories = category.present? ? category.child_categories : Category
        category = categories.where(external_id: external_id).first
        if category.nil?
          puts 'NOTHING'
          puts external_id
          puts categories.inspect
        end
      end
      question_text = question['text'].gsub(/[[:space:]]/, ' ').strip
      if question_text.index('*').nil?
        category.questions.create(
          text: question_text,
          option1: question['answers'][0],
          option2: question['answers'][1],
          option3: question['answers'][2],
          option4: question['answers'][3],
          option5: question['answers'][4]
        )
      else
        variations.each do |variation|
          category.questions.create(
            text: question_text.gsub('.*', variation),
            option1: question['answers'][0],
            option2: question['answers'][1],
            option3: question['answers'][2],
            option4: question['answers'][3],
            option5: question['answers'][4]
          )
        end
      end
    end
  end

  desc 'Load in student and teacher responses'
  task load_student_responses: :environment do
    ENV['BULK_PROCESS'] = 'true'
    answer_dictionary = {
      'Slightly': 'Somewhat',
      'an incredible': 'a tremendous',
      'a little': 'a little bit',
      'slightly': 'somewhat',
      'a little well': 'slightly well',
      'quite': 'very',
      'a tremendous': 'a very great',
      'somewhat clearly': 'somewhat',
      'almost never': 'once in a while',
      'always': 'all the time',
      'not at all strong': 'not strong at all',
      'each': 'every'
    }
    respondent_map = {}

    unknown_schools = {}
    missing_questions = {}
    bad_answers = {}
    year = '2016'
    ['student_responses', 'teacher_responses'].each do |file|
      recipients = file.split('_')[0]
      target_group = Question.target_groups["for_#{recipients}s"]
      csv_string = File.read(File.expand_path("../../../data/#{file}_#{year}.csv", __FILE__))
      csv = CSV.parse(csv_string, :headers => true)
      csv.each do |row|
        school_name = row['What school do you go to?']
        school_name = row['What school do you work at'] if school_name.nil?
        school = School.find_by_name(school_name)

        if school.nil?
          next if unknown_schools[school_name]
          puts "Unable to find school: #{school_name}"
          unknown_schools[school_name] = true
          next
        end

        recipient_list = school.recipient_lists.find_by_name("#{recipients.titleize} List")
        if recipient_list.nil?
          school.recipient_lists.create(name: "#{recipients.titleize} List")
        end

        respondent_id = row['RespondentID']
        recipient_id = respondent_map[respondent_id]
        if recipient_id.present?
          recipient = school.recipients.where(id: recipient_id).first
        else
          recipient = school.recipients.create(
            name: "Survey Respondent Id: #{respondent_id}"
          )
          respondent_map[respondent_id] = recipient.id
        end
        recipient_list.recipient_id_array << recipient.id
        recipient_list.save!

        row.each do |key, value|
          next if value.nil? or key.nil?
          key = key.gsub(/[[:space:]]/, ' ').strip
          value = value.gsub(/[[:space:]]/, ' ').strip.downcase
          question = Question.find_by_text(key)
          if question.nil?
            next if missing_questions[key]
            puts "Unable to find question: #{key}"
            missing_questions[key] = true
            next
          else
            question.update_attributes(target_group: target_group) if question.unknown?
          end

          answer_index = question.option_index(value)
          answer_dictionary.each do |k, v|
            break if answer_index.present?
            answer_index = question.option_index(value.gsub(k.to_s, v.to_s))
            answer_index = question.option_index(value.gsub(v.to_s, k.to_s)) if answer_index.nil?
          end

          if answer_index.nil?
            next if bad_answers[key]
            puts "Unable to find answer: #{key} = #{value.downcase.strip} - #{question.options.inspect}"
            bad_answers[key] = true
            next
          end

          responded_at = Date.strptime(row['EndDate'], '%m/%d/%Y %H:%M:%S')
          recipient.attempts.create(question: question, answer_index: answer_index + 1, responded_at: responded_at)
        end
      end
    end
    ENV.delete('BULK_PROCESS')

    SchoolCategory.all.each { |sc| sc.sync_aggregated_responses }
  end
end
