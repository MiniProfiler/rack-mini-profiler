# frozen_string_literal: true

describe Rack::MiniProfiler::TimerStruct::Base do

  before do
    @timer = Rack::MiniProfiler::TimerStruct::Base.new('Mini' => 'Profiler')
  end

  it 'has the the Mini attribute' do
    expect(@timer['Mini']).to eq('Profiler')
  end

  it 'allows us to set any attribute we want' do
    @timer[:hello] = 'World'
    expect(@timer[:hello]).to eq('World')
  end

  describe 'to_json' do

    before do
      @timer[:ice_ice] = 'Baby'
      @json = @timer.to_json
    end

    it 'has a JSON value' do
      expect(@json).not_to be_nil
    end

    it 'should not add a second (nil) argument if no arguments were passed' do
      expect(::JSON).to receive(:generate).once.with(@timer.attributes, max_nesting: 100).and_return(nil)
      @timer.to_json
    end

    describe 'deserialized' do

      before do
        @deserialized = ::JSON.parse(@json)
      end

      it 'produces a hash' do
        expect(@deserialized.is_a?(Hash)).to be(true)
      end

      it 'has the element we added' do
        expect(@deserialized['ice_ice']).to eq('Baby')
      end
    end

  end

end
