<tr class="${s.row_class}" data-timing-id="${s.parent_timing_id}">
  <td class="profiler-info">
    <div>${s.parent_timing_name}</div>
    <div class="profiler-number"><span class="profiler-unit">T+</span>${MiniProfiler.formatDuration(s.start_milliseconds)} <span class="profiler-unit">ms</span></div>
    <div>
      {{if s.is_duplicate}}<span class="profiler-warning">DUPLICATE</span>{{/if}}
      ${MiniProfiler.renderExecuteType(s.execute_type)}
    </div>
    <div title="{{if s.execute_type == 3}}first result fetched: ${s.first_fetch_duration_milliseconds}ms{{/if}}">${MiniProfiler.formatDuration(s.duration_milliseconds)} <span class="profiler-unit">ms</span></div>
  </td>
  <td>
    <div class="query">
      <pre class="profiler-stack-trace">${s.stack_trace_snippet}</pre>
      <pre class="prettyprint lang-sql"><code>${s.formatted_command_string}; ${MiniProfiler.formatParameters(s.parameters)}</code></pre>
    </div>
  </td>
</tr>
