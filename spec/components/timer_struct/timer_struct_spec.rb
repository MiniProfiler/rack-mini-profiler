require 'spec_helper'

describe Rack::MiniProfiler::TimerStruct::Base do

  before do
    @timer = Rack::MiniProfiler::TimerStruct::Base.new('Mini' => 'Profiler')
  end

  it 'has the the Mini attribute' do
    @timer['Mini'].should == 'Profiler'
  end

  it 'allows us to set any attribute we want' do
    @timer[:hello] = 'World'
    @timer[:hello].should == 'World'
  end

  describe 'to_json' do

    before do
      @timer[:ice_ice] = 'Baby'
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
        @deserialized['ice_ice'].should == 'Baby'
      end
    end

  end

end
