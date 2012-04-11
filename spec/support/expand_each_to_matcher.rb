# This defines a matcher we can use to test the result of an each method on an object
RSpec::Matchers.define :expand_each_to do |expected|  
  match do |actual|
    expanded = []
    actual.each {|v| expanded << v}
    expanded.should == expected
  end
end