# frozen_string_literal: true

module Rack
  puts <<~MSG
    [RackMiniProfiler] prepend_net_http_patch is now applied by default.
    Please do not require it any longer. It will be removed in a future version.
  MSG
end
