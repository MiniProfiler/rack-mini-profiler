require 'spec_helper'

# this enables activerecord, and allows us to test the auto detection logic
require 'active_record'

describe SqlPatches do
  # and patched= to some extent
  describe ".all_patch_files" do
    it "uses env variable" do
      with_patch_env("custom1") do
        expect(SqlPatches.all_patch_files).to eq(["custom1"])
      end
    end

    it "uses supports multiple env variable" do
      with_patch_env("custom1,custom2") do
        expect(SqlPatches.all_patch_files).to eq(["custom1", "custom2"])
      end
    end

    it "strips whitespace from env variable" do
      with_patch_env("custom1, custom2") do
        expect(SqlPatches.all_patch_files).to eq(["custom1", "custom2"])
      end
    end

    it "allows env var to turn off" do
      with_patch_env("false") do
        expect(SqlPatches.all_patch_files).to eq([])
      end
    end

    it "uses detection of env variable is not defined" do
      with_patch_env(nil) do
        expect(SqlPatches.all_patch_files).to eq(["activerecord"])
      end
    end
  end

  def with_patch_env(value)
    old_value = ENV["RACK_MINI_PROFILER_PATCH"]
    ENV["RACK_MINI_PROFILER_PATCH"] = value
    yield
  ensure
    ENV["RACK_MINI_PROFILER_PATCH"] = old_value
  end
end
