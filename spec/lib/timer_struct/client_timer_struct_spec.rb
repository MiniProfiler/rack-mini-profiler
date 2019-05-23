# frozen_string_literal: true

require 'yaml'

describe Rack::MiniProfiler::TimerStruct::Client do

  let(:described) { Rack::MiniProfiler::TimerStruct::Client }

  def new_page
    Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  def fixture(name)
    YAML.load(File.open(File.dirname(__FILE__) + "/../../fixtures/#{name}.yml"))
  end

  before do
    @client = described.new
  end

  it 'defaults to no attributes' do
    expect(::JSON.parse(@client.to_json)).to be_empty
  end

  describe 'init_from_form_data' do

    describe 'without a form' do
      before do
        @client = described.init_from_form_data({}, new_page)
      end

      it 'is null' do
        expect(@client).to be_nil
      end
    end

    describe 'init_instrumentation' do
      it "returns the body of mPt js function" do
        expect(described.init_instrumentation).to match(/mPt/)
      end
    end

    describe 'instrument' do
      it "works" do
        expected = "<script>mPt.probe('a')</script>b<script>mPt.probe('a')</script>b"
        expect(described.instrument('a', 'b')).to eq(expected)
      end
    end

    describe 'with a simple request' do
      before do
        @client = described.init_from_form_data(fixture(:simple_client_request), new_page)
      end

      it 'has the correct RedirectCount' do
        expect(@client[:redirect_count]).to eq(1)
      end

      it 'has Timings' do
        expect(@client.timings).not_to be_empty
      end

      describe "bob.js" do
        before do
          @bob = @client.timings.find { |t| t["Name"] == "bob.js" }
        end

        it 'has it in the timings' do
          expect(@bob).not_to be_nil
        end

        it 'has the correct duration' do
          expect(@bob['Duration']).to eq(6)
        end

      end

      describe "Navigation" do
        before do
          @nav = @client.timings.find { |t| t["Name"] == "Navigation" }
        end

        it 'has a Timing for the Navigation' do
          expect(@nav).not_to be_nil
        end

        it 'has the correct start' do
          expect(@nav['Start']).to eq(0)
        end

        it 'has the correct duration' do
          expect(@nav['Duration']).to eq(16)
        end
      end

      describe "Simple" do
        before do
          @simple = @client.timings.find { |t| t["Name"] == "Simple" }
        end

        it 'has a Timing for the Simple' do
          expect(@simple).not_to be_nil
        end

        it 'has the correct start' do
          expect(@simple['Start']).to eq(1)
        end

        it 'has the correct duration' do
          expect(@simple['Duration']).to eq(10)
        end
      end

    end

    describe 'with some odd values' do
      before do
        @client = described.init_from_form_data(fixture(:weird_client_request), new_page)
      end

      it 'has the correct redirect_count' do
        expect(@client.redirect_count).to eq(99)
      end

      it 'has Timings' do
        expect(@client.timings).not_to be_empty
      end

      it 'has no timing when the start is before Navigation' do
        expect(@client.timings.find { |t| t["Name"] == "Previous" }).to be_nil
      end

      describe "weird" do
        before do
          @weird = @client.timings.find { |t| t["Name"] == "Weird" }
        end

        it 'has a Timing for the Weird' do
          expect(@weird).not_to be_nil
        end

        it 'has the correct start' do
          expect(@weird['Start']).to eq(11)
        end

        it 'has a 0 duration because start time is greater than end time' do
          expect(@weird['Duration']).to eq(0)
        end
      end

      describe "differentFormat" do
        before do
          @diff = @client.timings.find { |t| t["Name"] == "differentFormat" }
        end

        it 'has a Timing for the differentFormat' do
          expect(@diff).not_to be_nil
        end

        it 'has the correct start' do
          expect(@diff['Start']).to eq(1)
        end

        it 'has a -1 duration because the format was different' do
          expect(@diff['Duration']).to eq(-1)
        end
      end
    end
  end
end
