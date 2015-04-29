require 'spec_helper'

describe Rack::MiniProfiler::TimerStruct::Request do

  def new_page
    Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  before do
    @name = 'cool request'
    @request = Rack::MiniProfiler::TimerStruct::Request.createRoot(@name, new_page)
  end

  it 'has an Id' do
    @request[:Id].should_not be_nil
  end

  it 'has a Root' do
    @request[:Name].should == @name
  end

  it 'has an empty Children attribute' do
    @request.children.should be_empty
  end

  it "has start time" do
    expect(@request.start).not_to be(0)
  end

  it 'has no sql timings at first' do
    @request.sql_timings.should be_empty
  end

  describe 'add SQL' do

    before do
      @page = new_page
      @request.add_sql("SELECT 1 FROM users", 77, @page)
    end

    it 'has the SqlTiming object' do
      @request.sql_timings.should_not be_empty
    end

    it 'has a child with the ParentTimingId of the request' do
      @request.sql_timings[0]['ParentTimingId'].should == @request['Id']
    end

  end

  describe 'add Custom' do
    before do
      @page = new_page
      @request.add_custom("a", 77, @page)
    end
    it "will be added to custom timings" do
      expect(@request.custom_timings.size).to eq(1)
      expect(@request.custom_timings.first[0]).to eq('a')
    end
  end

  describe 'record time' do

    describe 'add children' do

      before do
        @child = @request.add_child('child')
        @child.record_time(1111)
      end

      it 'has the child in the Children attribute' do
        @request[:Children].should == [@child]
      end

      describe 'record time on parent' do
        before do
          @request.record_time(1234)
        end

        it 'has stores the recorded time in DurationMilliseconds' do
          @request.duration_ms.should == 1234
        end
      end
    end
  end
end
