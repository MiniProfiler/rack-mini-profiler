# inspired by https://github.com/brendangregg/FlameGraph

class Rack::MiniProfiler::FlameGraph
  def initialize(stacks)
    @stacks = stacks
  end

  def graph_data
    height = 0 

    table = [] 
    prev = []

    # a 2d array makes collapsing easy
    @stacks.each_with_index do |stack, pos|
      col = []

      stack.reverse.map{|r| r.to_s}.each_with_index do |frame, i|

        if !prev[i].nil? 
          last_col = prev[i]
          if last_col[0] == frame
            last_col[1] += 1
            col << nil
            next
          end
        end

        prev[i] = [frame, 1] 
        col << prev[i]
      end
      prev = prev[0..col.length-1].to_a
      table << col
    end

    data = []

    # a 1d array makes rendering easy
    table.each_with_index do |col, col_num|
      col.each_with_index do |row, row_num|
        next unless row && row.length == 2
        data << {
          :x => col_num + 1,
          :y => row_num + 1,
          :width => row[1],
          :frame => row[0]
        }
      end
    end

    data
  end

end
