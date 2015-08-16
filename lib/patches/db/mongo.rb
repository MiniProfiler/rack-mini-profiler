# Mongo/Mongoid 5 patches
class Mongo::Server::Connection
  def dispatch_with_timing(*args, &blk)
    return dispatch_without_timing(*args, &blk) unless SqlPatches.should_measure?

    result, _record = SqlPatches.record_sql(args[0][0].payload.inspect) do
      dispatch_without_timing(*args, &blk)
    end
    return result
  end
  alias_method_chain :dispatch, :timing
end
