require 'spec_helper'
require 'yaml'

describe Rack::MiniProfiler::TimerStruct::Client do

  let(:described){ Rack::MiniProfiler::TimerStruct::Client }

  def new_page
    Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  def fixture(name)
    YAML.load(File.open(File.dirname(__FILE__) + "/../../fixtures/#{name}.yml"))
  end

  before do
    @client = described.new
  end

  it 'defaults to no attributes' do
    ::JSON.parse(@client.to_json).should be_empty
  end

  describe 'init_from_form_data' do

    describe 'without a form' do
      before do
        @client = described.init_from_form_data({}, new_page)
      end

      it 'is null' do
        @client.should be_nil
      end
    end

    describe 'init_instrumentation' do
      it "returns the body of mPt js function" do
        expect(described.init_instrumentation).to match(/mPt/)
      end
    end

    describe 'instrument' do
      it "works" do
        expected = "<script>mPt.probe('a')</script>b<script>mPt.probe('a')</script>b"
        expect(described.instrument('a', 'b')).to eq(expected)
      end
    end

    describe 'with a simple request' do
      before do
        @client = described.init_from_form_data(fixture(:simple_client_request), new_page)
      end

      it 'has the correct RedirectCount' do
        @client[:redirect_count].should == 1
      end

      it 'has Timings' do
        @client.timings.should_not be_empty
      end

      describe "bob.js" do
        before do
          @bob = @client.timings.find {|t| t["Name"] == "bob.js"}
        end

        it 'has it in the timings' do
          @bob.should_not be_nil
        end

        it 'has the correct duration' do
          @bob['Duration'].should == 6
        end

      end

      describe "Navigation" do
        before do
          @nav = @client.timings.find {|t| t["Name"] == "Navigation"}
        end

        it 'has a Timing for the Navigation' do
          @nav.should_not be_nil
        end

        it 'has the correct start' do
          @nav['Start'].should == 0
        end

        it 'has the correct duration' do
          @nav['Duration'].should == 16
        end
      end

      describe "Simple" do
        before do
          @simple = @client.timings.find {|t| t["Name"] == "Simple"}
        end

        it 'has a Timing for the Simple' do
          @simple.should_not be_nil
        end

        it 'has the correct start' do
          @simple['Start'].should == 1
        end

        it 'has the correct duration' do
          @simple['Duration'].should == 10
        end
      end

    end

    describe 'with some odd values' do
      before do
        @client = described.init_from_form_data(fixture(:weird_client_request), new_page)
      end

      it 'has the correct redirect_count' do
        @client.redirect_count.should == 99
      end

      it 'has Timings' do
        @client.timings.should_not be_empty
      end

      it 'has no timing when the start is before Navigation' do
        @client.timings.find {|t| t["Name"] == "Previous"}.should be_nil
      end

      describe "weird" do
        before do
          @weird = @client.timings.find {|t| t["Name"] == "Weird"}
        end

        it 'has a Timing for the Weird' do
          @weird.should_not be_nil
        end

        it 'has the correct start' do
          @weird['Start'].should == 11
        end

        it 'has a 0 duration because start time is greater than end time' do
          @weird['Duration'].should == 0
        end
      end

      describe "differentFormat" do
        before do
          @diff = @client.timings.find {|t| t["Name"] == "differentFormat"}
        end

        it 'has a Timing for the differentFormat' do
          @diff.should_not be_nil
        end

        it 'has the correct start' do
          @diff['Start'].should == 1
        end

        it 'has a -1 duration because the format was different' do
          @diff['Duration'].should == -1
        end
      end
    end
  end
end
