require 'test_helper'

class Admin::SurveysControllerTest < ActionDispatch::IntegrationTest

  def authorized_headers
    return {
      Authorization: ActionController::HttpAuthentication::Basic.encode_credentials(
        Rails.application.credentials.test[:authentication][:admin][:username],
        Rails.application.credentials.test[:authentication][:admin][:password]
      )
    }
  end

  def test_authentication
    # get the admin page
    get "/admin/surveys/new"
    assert_equal 401, status

    # post the login and follow through to the home page
    get "/admin/surveys/new", headers: authorized_headers
    assert_equal "/admin/surveys/new", path
  end

  def test_new_has_form
    get "/admin/surveys/new", headers: authorized_headers
    assert_select "form"
    assert_select "input.form-check-input", Question.count
  end

  def test_create__requirements
    survey_count = Survey.count
    post "/admin/questions", headers: authorized_headers
    assert_select "p", "Invalid Parameters"
    assert_equal survey_count, Survey.count

    post "/admin/surveys", headers: authorized_headers, params: {
      survey: {
        name: ""
      }
    }
    assert_select "li", "Name can't be blank"
    assert_equal survey_count, Survey.count

    survey = Survey.last
    post "/admin/surveys", headers: authorized_headers, params: {
      question: {
        name: "New Survey",
        questions: [Question.first.id, Question.last.id].join(',')
      }
    }
    assert_equal survey_count + 1, Survey.count
    assert_equal 302, status
    follow_redirect!

    survey = Survey.last
    assert_equal "/admin/survey/#{survey.id}", path
    assert_equal 2, survey.questions.count
  end

  def test_show
    survey = surveys(:two)
    get "/admin/surveys/#{survey.id}", headers: authorized_headers

    assert_select "h2", survey.name
    assert_select "a", survey.questions.first.text
  end

  # def test_index
  #   get "/admin/categories", headers: authorized_headers
  #   assert_select "h2", "All Categories"
  #   Category.all.each do |c|
  #     assert_select "a", c.name, href: admin_category_path(c)
  #   end
  # end

  # def test_index
  #   get "/admin/categories", headers: authorized_headers
  #   assert_select "h2", "All Categories"
  #   Category.all.each do |c|
  #     assert_select "a", c.name, href: admin_category_path(c)
  #   end
  # end
  #
  # test "should get edit" do
  #   get edit_survey_url(@survey)
  #   assert_response :success
  # end
  #
  # test "should update survey" do
  #   patch survey_url(@survey), params: { survey: { name: @survey.name, survey_monkey_id: @survey.survey_monkey_id } }
  #   assert_redirected_to survey_url(@survey)
  # end
  #
  # test "should destroy survey" do
  #   assert_difference('Survey.count', -1) do
  #     delete survey_url(@survey)
  #   end
  #
  #   assert_redirected_to surveys_url
  # end

end
