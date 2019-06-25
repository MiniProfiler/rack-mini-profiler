# frozen_string_literal: true

describe Rack::MiniProfiler::TimerStruct::Request do

  def new_page
    Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  before do
    @name = 'cool request'
    @more_path = 'http://localhost:3000/posts'
    @request = Rack::MiniProfiler::TimerStruct::Request.createRoot(@name, @more_path, new_page)
  end

  it 'sets IsRoot to true' do
    expect(@request[:is_root]).to be(true)
  end

  it 'has an Id' do
    expect(@request[:id]).not_to be_nil
  end

  it 'has a Root' do
    expect(@request[:name]).to eq(@name)
  end

  it 'has a path' do
    expect(@request[:more_path]).to eq(@more_path)
  end

  it 'begins with a children duration of 0' do
    expect(@request.children_duration).to eq(0)
  end

  it 'has a false HasChildren attribute' do
    expect(@request[:has_children]).to be(false)
  end

  it 'has an empty Children attribute' do
    expect(@request.children).to be_empty
  end

  it 'has a depth of 0' do
    expect(@request.depth).to eq(0)
  end

  it "has start time" do
    expect(@request.start).not_to be(0)
  end

  it 'has a false HasSqlTimings attribute' do
    expect(@request[:has_sql_timings]).to be(false)
  end

  it 'has no sql timings at first' do
    expect(@request[:sql_timings]).to be_empty
  end

  it 'has a 0 for sql_timings_duration_milliseconds' do
    expect(@request[:sql_timings_duration_milliseconds]).to eq(0)
  end

  describe 'add SQL' do

    before do
      @page = new_page
      @request.add_sql("SELECT 1 FROM users", 77, @page)
    end

    it 'has a true HasSqlTimings attribute' do
      expect(@request[:has_sql_timings]).to be(true)
    end

    it 'has the SqlTiming object' do
      expect(@request.sql_timings).not_to be_empty
    end

    it 'has a child with the ParentTimingId of the request' do
      expect(@request.sql_timings[0]['ParentTimingId']).to eq(@request['Id'])
    end

    it 'increases sql_timings_duration_milliseconds' do
      expect(@request[:sql_timings_duration_milliseconds]).to eq(77)
    end

    it "increases the page's " do
      expect(@page[:duration_milliseconds_in_sql]).to eq(77)
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

      it 'has a is_root value of false' do
        expect(@child[:is_root]).to be(false)
      end

      it 'has a true HasChildren attribute' do
        expect(@request[:has_children]).to be(true)
      end

      it 'has the child in the Children attribute' do
        expect(@request[:children]).to eq([@child])
      end

      it 'assigns its Id to the child' do
        expect(@child[:parent_timing_id]).to eq(@request[:id])
      end

      it 'assigns a depth of 1 to the child' do
        expect(@child[:depth]).to eq(1)
      end

      it 'increases the children duration' do
        expect(@request.children_duration).to eq(1111)
      end

      it 'marks short timings as trivial' do
        @request.record_time(1)
        expect(@request[:is_trivial]).to be(true)
      end

      describe 'record time on parent' do
        before do
          @request.record_time(1234)
        end

        it "is not a trivial query" do
          expect(@request[:is_trivial]).to be(false)
        end

        it 'has stores the recorded time in DurationMilliseconds' do
          expect(@request.duration_ms).to eq(1234)
        end

        it 'calculates DurationWithoutChildrenMilliseconds without the children timings' do
          expect(@request[:duration_without_children_milliseconds]).to eq(123)
        end

      end
    end
  end
end
