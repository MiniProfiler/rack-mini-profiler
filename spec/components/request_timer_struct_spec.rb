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

  it 'sets is_root to true' do
    @request[:is_root].should be_true
  end

  it 'has an id' do
    @request[:id].should_not be_nil
  end

  it 'has a root' do
    @request[:name].should == @name
  end

  it 'begins with a children duration of 0' do
    @request.children_duration.should == 0
  end

  it 'has a false has_children attribute' do
    @request[:has_children].should be_false
  end

  it 'has an empty children attribute' do
    @request[:children].should be_empty
  end

  it 'has a depth of 0' do
    @request[:depth].should == 0
  end

  it 'has a false has_sql_timings attribute' do
    @request[:has_sql_timings].should be_false
  end

  it 'has no sql timings at first' do
    @request[:sql_timings].should be_empty
  end

  it 'has a 0 for sql_timings_duration_milliseconds' do
    @request[:sql_timings_duration_milliseconds].should == 0
  end

  describe 'add SQL' do

    before do
      @page = new_page
      @request.add_sql("SELECT 1 FROM users", 77, @page)
    end

    it 'has a true has_sql_timings attribute' do
      @request[:has_sql_timings].should be_true
    end

    it 'has the sql_timing object' do
      @request[:sql_timings].should_not be_empty
    end

    it 'has a child with the parent_timing_id of the request' do
      @request[:sql_timings][0][:parent_timing_id].should == @request[:id]
    end

    it 'increases sql_timings_duration_milliseconds' do
      @request[:sql_timings_duration_milliseconds].should == 77
    end

    it "increases the page's " do
      @page[:duration_milliseconds_in_sql].should == 77
    end

  end

  describe 'record time' do

    describe 'add children' do

      before do
        @child = @request.add_child('child')
        @child.record_time(1111)
      end

      it 'has a is_root value of false' do
        @child[:is_root].should be_false
      end

      it 'has a true has_children attribute' do
        @request[:has_children].should be_true
      end

      it 'has the child in the children attribute' do
        @request[:children].should == [@child]
      end

      it 'assigns its id to the child' do
        @child[:parent_timing_id].should == @request[:id]
      end

      it 'assigns a depth of 1 to the child' do
        @child[:depth].should == 1
      end

      it 'increases the children duration' do
        @request.children_duration.should == 1111
      end

      it 'marks short timings as trivial' do
        @request.record_time(1)
        @request[:is_trivial].should be_true
      end

      describe 'record time on parent' do
        before do
          @request.record_time(1234)
        end

        it "is not a trivial query" do
          @request[:is_trivial].should be_false
        end

        it 'has stores the recorded time in duration_milliseconds' do
          @request[:duration_milliseconds].should == 1234
        end

        it 'calculates duration_without_children_milliseconds without the children timings' do
          @request[:duration_without_children_milliseconds].should == 123
        end
      end
    end
  end

end
