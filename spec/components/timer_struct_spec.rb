require 'spec_helper'
require 'mini_profiler/timer_struct'

require 'json'

describe Rack::MiniProfiler::TimerStruct do

  before do
    @timer = Rack::MiniProfiler::TimerStruct.new('Mini' => 'Profiler')
  end

  it 'has the the Mini attribute' do
    @timer['Mini'].should == 'Profiler'
  end

  it 'allows us to set any attribute we want' do
    @timer['Hello'] = 'World'
    @timer['Hello'].should == 'World'
  end

  describe 'to_json' do

    before do
      @timer['IceIce'] = 'Baby'
      @json = @timer.to_json
    end

    it 'has a JSON value' do
      @json.should_not be_nil
    end

    it 'should not add a second (nil) argument if no arguments were passed' do
      ::JSON.should_receive( :generate ).once.with( @timer.attributes, :max_nesting => 100 ).and_return( nil )
      @timer.to_json
    end

    describe 'deserialized' do

      before do
        @deserialized = ::JSON.parse(@json)
      end

      it 'produces a hash' do
        @deserialized.is_a?(Hash).should be_true
      end

      it 'has the element we added' do
        @deserialized['IceIce'].should == 'Baby'
      end
    end

  end

end
