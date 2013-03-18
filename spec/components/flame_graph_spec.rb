require 'spec_helper'
require 'rack-mini-profiler'
require 'mini_profiler/flame_graph'

describe Rack::MiniProfiler::FlameGraph do 

  it "builds a table correctly" do 
    stacks = [["3","2","1"],["4","1"],["4","5"]]

    g = Rack::MiniProfiler::FlameGraph.new(stacks)
    
    g.graph_data.should == [ 
        {:x => 1, :y => 1, :frame => "1", :width => 2}, 
        {:x => 1, :y => 2, :frame => "2", :width => 1}, 
        {:x => 1, :y => 3, :frame => "3", :width => 1}, 
        {:x => 2, :y => 2, :frame => "4", :width => 2}, 
        {:x => 3, :y => 1, :frame => "5", :width => 1} 
    ]

  end


  it "avoids bridges" do 
    stacks = [["3","2","1"],["1"],["3","2","1"]]
    
    g = Rack::MiniProfiler::FlameGraph.new(stacks)

    g.graph_data.should == [ 
        {:x => 1, :y => 1, :frame => "1", :width => 3}, 
        {:x => 1, :y => 2, :frame => "2", :width => 1}, 
        {:x => 1, :y => 3, :frame => "3", :width => 1}, 
        {:x => 3, :y => 2, :frame => "2", :width => 1}, 
        {:x => 3, :y => 3, :frame => "3", :width => 1} 
    ]
  end

end
