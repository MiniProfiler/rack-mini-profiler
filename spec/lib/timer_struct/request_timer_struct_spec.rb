# frozen_string_literal: true

describe Rack::MiniProfiler::TimerStruct::Request do

  def new_page
    Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  def origin_and_destination(req)
    [req.add_child('origin'), req.add_child('destination')]
  end

  before do
    @name = 'cool request'
    @request = Rack::MiniProfiler::TimerStruct::Request.createRoot(@name, new_page)
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

  it 'begins with a children duration of 0' do
    expect(@request.children.sum(&:duration_ms)).to eq(0)
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
        expect(@request.children.sum(&:duration_ms)).to eq(1111)
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

  describe '#move_child' do
    before do
      @origin, @destination = origin_and_destination(@request)
      @child = @origin.add_child('child')
      @origin.move_child(@child, @destination)
    end

    it 'updates children attribute' do
      expect(@origin.children).to eq([])
      expect(@destination.children).to eq([@child])
    end

    it 'updates has_children attribute' do
      expect(@origin[:has_children]).to eq(false)
      expect(@destination[:has_children]).to eq(true)
    end

    it 'updates parent_timing_id attribute' do
      expect(@child[:parent_timing_id]).to eq(@destination[:id])
    end

    it 'updates parent attribute' do
      expect(@child.parent).to eq(@destination)
    end
  end

  context 'when moving to different depth' do
    describe '#move_child' do
      before do
        @origin = @request.add_child('origin')
        @destination_parent = @request.add_child('destination_parent')
        @destination = @destination_parent.add_child('destination')
        @child = @origin.add_child('child')
        @origin.move_child(@child, @destination)
      end

      it 'updates depth correctly' do
        expect(@child[:depth]).to eq(@destination[:depth] + 1)
        expect(@destination[:depth]).to eq(@destination_parent[:depth] + 1)
        expect(@destination_parent[:depth]).to eq(@origin[:depth])
      end
    end
  end

  describe '#move_sql' do
    before do
      @page = new_page
      @origin, @destination = origin_and_destination(@request)
      @sql = @origin.add_sql('SELECT 1;', 30, @page)
      @origin.move_sql(@sql, @destination)
    end

    it 'updates sql_timings_duration_milliseconds attribute' do
      expect(@origin[:sql_timings_duration_milliseconds]).to eq(0)
      expect(@destination[:sql_timings_duration_milliseconds]).to eq(30)
    end

    it 'updates parent_timing_id and parent attributes' do
      expect(@sql[:parent_timing_id]).to eq(@destination[:id])
      expect(@sql.parent).to eq(@destination)
    end

    it "doesn't increase duration_milliseconds_in_sql and sql_count attributes of the page" do
      expect(@page[:duration_milliseconds_in_sql]).to eq(30)
      expect(@page[:sql_count]).to eq(1)
    end
  end

  context 'when origin has one sql' do
    describe '#move_sql' do
      before do
        @page = new_page
        @origin, @destination = origin_and_destination(@request)
        @sql = @origin.add_sql('SELECT 1;', 30, @page)
        @origin.move_sql(@sql, @destination)
      end

      it 'updates sql_timings attribute' do
        expect(@origin[:sql_timings]).to eq([])
        expect(@destination[:sql_timings]).to eq([@sql])
      end

      it 'updates has_sql_timings attribute' do
        expect(@origin[:has_sql_timings]).to eq(false)
        expect(@destination[:has_sql_timings]).to eq(true)
      end
    end
  end

  context 'when origin has more than one sql' do
    describe '#move_sql' do
      before do
        @page = new_page
        @origin, @destination = origin_and_destination(@request)
        @sql = @origin.add_sql('SELECT 1;', 30, @page)
        @sql_2 = @origin.add_sql('SELECT 2;', 40, @page)
        @origin.move_sql(@sql, @destination)
      end

      it 'updates sql_timings attribute' do
        expect(@origin[:sql_timings]).to eq([@sql_2])
        expect(@destination[:sql_timings]).to eq([@sql])
      end

      it 'updates has_sql_timings attribute' do
        expect(@origin[:has_sql_timings]).to eq(true)
        expect(@destination[:has_sql_timings]).to eq(true)
      end
    end
  end

  describe '#move_custom' do
    before do
      @page = new_page
      @origin, @destination = origin_and_destination(@request)
      @custom = @origin.add_custom('tests', 30, @page)
      @origin.move_custom('tests', @custom, @destination)
    end

    it 'updates parent_timing_id and parent attributes' do
      expect(@custom[:parent_timing_id]).to eq(@destination[:id])
      expect(@custom.parent).to eq(@destination)
    end
  end

  context 'when origin has one custom timings of the type' do
    before do
      @page = new_page
      @origin, @destination = origin_and_destination(@request)
      @custom = @origin.add_custom('tests', 30, @page)
      @origin.move_custom('tests', @custom, @destination)
    end

    it 'updates custom_timings and custom_timing_stats attributes' do
      expect(@origin[:custom_timings]).to eq({})
      expect(@origin[:custom_timing_stats]).to eq({})
      expect(@destination[:custom_timings]).to eq('tests' => [@custom])
      expect(@destination[:custom_timing_stats]).to eq('tests' => { count: 1, duration: 30 })
    end
  end

  context 'when origin has more than one custom timings of the same type' do
    before do
      @page = new_page
      @origin, @destination = origin_and_destination(@request)
      @custom = @origin.add_custom('tests', 30, @page)
      @custom_2 = @origin.add_custom('tests', 50, @page)
      @origin.move_custom('tests', @custom, @destination)
    end

    it 'updates custom_timings and custom_timing_stats attributes' do
      expect(@origin[:custom_timings]).to eq('tests' => [@custom_2])
      expect(@origin[:custom_timing_stats]).to eq('tests' => { count: 1, duration: 50 })
      expect(@destination[:custom_timings]).to eq('tests' => [@custom])
      expect(@destination[:custom_timing_stats]).to eq('tests' => { count: 1, duration: 30 })
    end
  end

  context 'when destination has more than one custom timings of the same type' do
    before do
      @page = new_page
      @origin, @destination = origin_and_destination(@request)
      @custom = @origin.add_custom('tests', 30, @page)
      @custom_2 = @destination.add_custom('tests', 50, @page)
      @origin.move_custom('tests', @custom, @destination)
    end

    it 'updates custom_timings and custom_timing_stats attributes' do
      expect(@origin[:custom_timings]).to eq({})
      expect(@origin[:custom_timing_stats]).to eq({})
      expect(@destination[:custom_timings]).to eq('tests' => [@custom_2, @custom])
      expect(@destination[:custom_timing_stats]).to eq('tests' => { count: 2, duration: 80 })
    end
  end

  context 'when there is parent' do
    describe '#adjust_depth' do
      before do
        @level_1 = @request.add_child('level 1')
        @level_2 = @level_1.add_child('level 2')
        @moved = @level_1.add_child('moved')
        2.times { |n| @moved.add_child("child #{n}") }
        @moved.parent = @level_2
        @moved.adjust_depth
      end

      it 'corrects the depth of the moved node and all its children' do
        expect(@level_2[:depth]).to eq(@level_1[:depth] + 1)
        expect(@moved[:depth]).to eq(@level_2[:depth] + 1)
        @moved.children.each { |child| expect(child[:depth]).to eq(@moved[:depth] + 1) }
      end
    end
  end

  context 'when there is no parent' do
    describe '#adjust_depth' do
      before do
        @moved = @request.add_child('moved')
        2.times { |n| @moved.add_child("child #{n}") }
        @moved.parent = nil
        @moved.adjust_depth
      end

      it 'sets depth to 0 and corrects children depth' do
        expect(@moved[:depth]).to eq(0)
        @moved.children.each { |child| expect(child[:depth]).to eq(1) }
      end
    end
  end
end
