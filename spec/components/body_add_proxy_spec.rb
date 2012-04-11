require 'spec_helper'
require 'mini_profiler/body_add_proxy'

describe Rack::MiniProfiler::BodyAddProxy do

  context 'body as an array' do

    before do
      @proxy = Rack::MiniProfiler::BodyAddProxy.new(%w(a b c), 'd')
    end

    it 'contains the appended value' do
      @proxy.should expand_each_to %w(a b c d)
    end

    describe 'delegation' do
      it 'delegates respond to <<' do
        @proxy.respond_to?('<<').should be_true
      end

      it 'delegates respond to first' do
        @proxy.respond_to?(:first).should be_true
      end    

      it 'delegates method_missing' do
        @proxy.first.should == 'a'
      end

    end

  end

  context 'body as a custom object' do

    # A class and a super class to help us test appending to a custom object, such as 
    # Rails' ActionDispatch::Response
    class Band
      def style
        'rock'
      end
    end    
    
    class Beatles < Band
      def each
        yield 'john'
        yield 'paul'
        yield 'george'
      end

      def fake_method; nil; end

      def method_missing(*args, &block)
        'yoko'
      end
    end

    before do
      @proxy = Rack::MiniProfiler::BodyAddProxy.new(Beatles.new, 'ringo')
    end

    it 'contains the appended value' do
      @proxy.should expand_each_to %w(john paul george ringo)
    end

    describe 'delegation' do
      it 'delegates respond to fake_method' do
        @proxy.respond_to?(:fake_method).should be_true
      end

      it 'delegates respond to a super class' do
        @proxy.respond_to?(:style).should be_true
      end      

      it 'delegates method_missing' do
        @proxy.doesnt_exist.should == 'yoko'
      end

    end

  end


end
