# frozen_string_literal: true

# Mongoid 3 patches
class Moped::Node
  alias_method :process_without_profiling, :process
  def process(*args, &blk)
    unless SqlPatches.should_measure?
      return process_without_profiling(*args, &blk)
    end

    result, _record =
      SqlPatches.record_sql(args[0].log_inspect) do
        process_without_profiling(*args, &blk)
      end
    result
  end
end
