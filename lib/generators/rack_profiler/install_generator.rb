# frozen_string_literal: true

module RackProfiler
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer_file
        copy_file "rack_profiler.rb", "config/initializers/rack_profiler.rb"
      end
    end
  end
end
