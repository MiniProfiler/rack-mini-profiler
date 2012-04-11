require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::ClientTimerStruct do

  before do
    @client = Rack::MiniProfiler::ClientTimerStruct.new({})
  end

  it 'defaults to no attributes' do
    ::JSON.parse(@client.to_json).should be_empty
  end

  # TODO: Write specs for init_from_form_data

end
