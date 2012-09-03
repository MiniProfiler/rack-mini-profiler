class Rack::MiniProfiler::Context
  attr_accessor :inject_js,:current_timer,:page_struct,:skip_backtrace,:full_backtrace,:discard, :mpt_init
  
  def initialize(opts = {})
    opts.each do |k,v|
      self.instance_variable_set('@' + k, v)
    end
  end

end
