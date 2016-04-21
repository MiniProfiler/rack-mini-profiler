require 'spec_helper'

describe SqlPatches do
  # and patched= to some extent
  describe ".patched?" do
    it "detects patched" do
      SqlPatches.patched = true

      expect(SqlPatches).to be_patched
    end

    it "detects unpatched" do
      SqlPatches.patched = false

      expect(SqlPatches).not_to be_patched
    end
  end

  describe ".unpatched?" do
    it "detects patched" do
      SqlPatches.patched = true

      expect(SqlPatches).not_to be_unpatched
    end

    it "detects unpatched" do
      SqlPatches.patched = false
      expect(SqlPatches).to be_unpatched
    end
  end
end
