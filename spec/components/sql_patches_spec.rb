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

  describe ".class_exists?(name)" do
    it "detects non-existant" do
      expect(SqlPatches.class_exists?("SomeRandomClassThatDoesntExist")).to eq(false)
    end

    it "detects module" do
      expect(SqlPatches.class_exists?("Rack")).to eq(false)
    end

    it "detects class" do
      expect(SqlPatches.class_exists?("SqlPatches")).to eq(true)
    end
  end

  describe ".module_exists?(name)" do
    it "detects non-existant" do
      expect(SqlPatches.module_exists?("SomeRandomClassThatDoesntExist")).to eq(false)
    end

    it "detects module" do
      expect(SqlPatches.module_exists?("Rack")).to eq(true)
    end

    it "detects class" do
      expect(SqlPatches.module_exists?("SqlPatches")).to eq(false)
    end
  end
end
