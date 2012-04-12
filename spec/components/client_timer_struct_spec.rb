require 'spec_helper'
require 'rack-mini-profiler'
require 'yaml'

describe Rack::MiniProfiler::ClientTimerStruct do

  def new_page
    Rack::MiniProfiler::PageTimerStruct.new({})
  end

  def fixture(name)
    YAML.load(File.open(File.dirname(__FILE__) + "/../fixtures/#{name}.yml"))
  end

  before do
    @client = Rack::MiniProfiler::ClientTimerStruct.new
  end

  it 'defaults to no attributes' do
    ::JSON.parse(@client.to_json).should be_empty
  end

  describe 'init_from_form_data' do

    describe 'without a form' do
      before do
        @client.init_from_form_data({}, new_page)
      end
      
      it 'has no Timings' do
        @client['Timings'].should be_nil
      end

      it 'has no RedirectCount' do
        @client['RedirectCount'].should be_nil
      end
    end

    describe 'with a simple request' do
      before do
        @client.init_from_form_data(fixture(:simple_client_request), new_page)
      end

      it 'has the correct RedirectCount' do
        @client['RedirectCount'].should == 1
      end

      it 'has Timings' do
        @client['Timings'].should_not be_empty
      end

      describe "Navigation" do
        before do
          @nav = @client['Timings'].find {|t| t["Name"] == "Navigation"}
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
          @simple = @client['Timings'].find {|t| t["Name"] == "Simple"}
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
        @client.init_from_form_data(fixture(:weird_client_request), new_page)        
      end

      it 'has the correct RedirectCount' do
        @client['RedirectCount'].should == 99
      end

      it 'has Timings' do
        @client['Timings'].should_not be_empty
      end

      it 'has no timing when the start is before Navigation' do          
        @client['Timings'].find {|t| t["Name"] == "Previous"}.should be_nil
      end
  
      describe "weird" do
        before do
          @weird = @client['Timings'].find {|t| t["Name"] == "Weird"}
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
          @diff = @client['Timings'].find {|t| t["Name"] == "differentFormat"}
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
