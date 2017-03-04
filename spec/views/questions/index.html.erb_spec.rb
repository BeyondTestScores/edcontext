require 'rails_helper'

RSpec.describe "questions/index", type: :view do
  before(:each) do
    assign(:questions, [
      Question.create!(
        :text => "Text",
        :option1 => "Option1",
        :option2 => "Option2",
        :option3 => "Option3",
        :option4 => "Option4",
        :option5 => "Option5",
        :category_id => 2
      ),
      Question.create!(
        :text => "Text",
        :option1 => "Option1",
        :option2 => "Option2",
        :option3 => "Option3",
        :option4 => "Option4",
        :option5 => "Option5",
        :category_id => 2
      )
    ])
  end

  it "renders a list of questions" do
    render
    assert_select "tr>td", :text => "Text".to_s, :count => 2
    assert_select "tr>td", :text => "Option1".to_s, :count => 2
    assert_select "tr>td", :text => "Option2".to_s, :count => 2
    assert_select "tr>td", :text => "Option3".to_s, :count => 2
    assert_select "tr>td", :text => "Option4".to_s, :count => 2
    assert_select "tr>td", :text => "Option5".to_s, :count => 2
    assert_select "tr>td", :text => 2.to_s, :count => 2
  end
end
