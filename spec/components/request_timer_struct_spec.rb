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

  it 'sets isRoot to true' do
    @request[:isRoot].should be_true
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

  it 'has a false hasChildren attribute' do
    @request[:hasChildren].should be_false
  end

  it 'has an empty children attribute' do
    @request[:children].should be_empty
  end

  it 'has a depth of 0' do
    @request[:depth].should == 0
  end

  it 'has a false hasSqlTimings attribute' do
    @request[:hasSqlTimings].should be_false
  end

  it 'has no sql timings at first' do
    @request[:sqlTimings].should be_empty
  end

  it 'has a 0 for sqlTimingsDurationMilliseconds' do
    @request[:sqlTimingsDurationMilliseconds].should == 0
  end

  describe 'add SQL' do

    before do
      @page = new_page
      @request.add_sql("SELECT 1 FROM users", 77, @page)
    end

    it 'has a true hasSqlTimings attribute' do
      @request[:hasSqlTimings].should be_true
    end

    it 'has the sqlTiming object' do
      @request[:sqlTimings].should_not be_empty
    end

    it 'has a child with the parentTimingId of the request' do
      @request[:sqlTimings][0][:parentTimingId].should == @request[:id]
    end

    it 'increases sqlTimingsDurationMilliseconds' do
      @request[:sqlTimingsDurationMilliseconds].should == 77
    end

    it "increases the page's " do
      @page[:durationMillisecondsInSql].should == 77
    end

  end

  describe 'record time' do

    describe 'add children' do

      before do
        @child = @request.add_child('child')
        @child.record_time(1111)
      end

      it 'has a isRoot value of false' do
        @child[:isRoot].should be_false
      end

      it 'has a true HasChildren attribute' do
        @request[:hasChildren].should be_true
      end

      it 'has the child in the children attribute' do
        @request[:children].should == [@child]
      end

      it 'assigns its id to the child' do
        @child[:parentTimingId].should == @request[:id]
      end

      it 'assigns a depth of 1 to the child' do
        @child[:depth].should == 1
      end

      it 'increases the children duration' do
        @request.children_duration.should == 1111
      end

      it 'marks short timings as trivial' do
        @request.record_time(1)
        @request[:isTrivial].should be_true
      end

      describe 'record time on parent' do
        before do
          @request.record_time(1234)
        end

        it "is not a trivial query" do
          @request[:isTrivial].should be_false
        end

        it 'has stores the recorded time in durationMilliseconds' do
          @request[:durationMilliseconds].should == 1234
        end

        it 'calculates durationWithoutChildrenMilliseconds without the children timings' do
          @request[:durationWithoutChildrenMilliseconds].should == 123
        end
      end
    end
  end

end
