require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::RequestTimerStruct do

  def new_page
    Rack::MiniProfiler::PageTimerStruct.new({})
  end

  before do
    @name = 'cool request'
    @request = Rack::MiniProfiler::RequestTimerStruct.createRoot(@name, new_page)
  end

  it 'sets IsRoot to true' do
    @request['IsRoot'].should be_true
  end

  it 'has an Id' do
    @request['Id'].should_not be_nil
  end

  it 'has a Root' do
    @request['Name'].should == @name
  end

  it 'begins with a children duration of 0' do
    @request.children_duration.should == 0
  end

  it 'has a false HasChildren attribute' do
    @request['HasChildren'].should be_false
  end

  it 'has an empty Children attribute' do
    @request['Children'].should be_empty
  end

  it 'has a depth of 0' do
    @request['Depth'].should == 0
  end

  it 'has a false HasSqlTimings attribute' do
    @request['HasSqlTimings'].should be_false
  end

  it 'has no sql timings at first' do
    @request['SqlTimings'].should be_empty    
  end

  it 'has a 0 for SqlTimingsDurationMilliseconds' do
    @request['SqlTimingsDurationMilliseconds'].should == 0
  end

  describe 'add SQL' do

    before do
      #def add_sql(query, elapsed_ms, page)
      @request.add_sql("SELECT 1 FROM users", 77, new_page)
    end

    it 'has a true HasSqlTimings attribute' do
      @request['HasSqlTimings'].should be_true
    end

    it 'has the SqlTiming object' do
      @request['SqlTimings'].should_not be_empty  
    end

    it 'has a child with the ParentTimingId of the request' do
      @request['SqlTimings'][0]['ParentTimingId'].should == @request['Id']
    end

    it 'increases SqlTimingsDurationMilliseconds' do
      @request['SqlTimingsDurationMilliseconds'].should == 77
    end

  end

  describe 'record time' do

    describe 'add children' do

      before do
        @child = Rack::MiniProfiler::RequestTimerStruct.new('child', new_page)
        @child.record_time(1111)        
        @request.add_child(@child)
      end

      it 'has a IsRoot value of false' do
        @child['IsRoot'].should be_false
      end

      it 'has a true HasChildren attribute' do
        @request['HasChildren'].should be_true
      end

      it 'has the child in the Children attribute' do
        @request['Children'].should == [@child]
      end      

      it 'assigns its Id to the child' do
        @child['ParentTimingId'].should == @request['Id']
      end

      it 'assigns a depth of 1 to the child' do
        @child['Depth'].should == 1
      end

      it 'increases the children duration' do
        @request.children_duration.should == 1111
      end


      describe 'record time on parent' do
        before do
          @request.record_time(1234)
        end

        it 'has stores the recorded time in DurationMilliseconds' do
          @request['DurationMilliseconds'].should == 1234
        end
        
        it 'calculates DurationWithoutChildrenMilliseconds without the children timings' do
          @request['DurationWithoutChildrenMilliseconds'].should == 123      
        end

      end

    end


  end


end
