
<tr class="{{if timing.is_trivial }}profiler-trivial{{/if}}" data-timing-id="${timing.id}">
  <td class="profiler-label" title="{{if timing.name && timing.name.length > 45 }}${timing.name}{{/if}}">
    <span class="profiler-indent">${MiniProfiler.renderIndent(timing.depth)}</span> ${timing.name.slice(0,45)}{{if timing.name && timing.name.length > 45 }}...{{/if}}
  </td>
  <td class="profiler-duration" title="duration of this step without any children's durations">
    ${MiniProfiler.formatDuration(timing.duration_without_children_milliseconds)}
  </td>
  <td class="profiler-duration profiler-duration-with-children" title="duration of this step and its children">
    ${MiniProfiler.formatDuration(timing.duration_milliseconds)}
  </td>
  <td class="profiler-duration time-from-start" title="time elapsed since profiling started">
    <span class="profiler-unit">+</span>${MiniProfiler.formatDuration(timing.start_milliseconds)}
  </td>

{{if timing.has_sql_timings}}
  <td class="profiler-duration {{if timing.has_duplicate_sql_timings}}profiler-warning{{/if}}" title="{{if timing.has_duplicate_sql_timings}}duplicate queries detected - {{/if}}{{if timing.executed_readers > 0 || timing.executed_scalars > 0 || timing.executed_non_queries > 0}}${timing.executed_readers} reader, ${timing.executed_scalars} scalar, ${timing.executed_non_queries} non-query statements executed{{/if}}">
    <a class="profiler-queries-show">
      {{if timing.has_duplicate_sql_timings}}<span class="profiler-nuclear">!</span>{{/if}}
      ${timing.sql_timings.length} <span class="profiler-unit">sql</span>
    </a>
  </td>
  <td class="profiler-duration" title="aggregate duration of all queries in this step (excludes children)">
    ${MiniProfiler.formatDuration(timing.sql_timings_duration_milliseconds)}
  </td>
{{else}}
  <td colspan="2"></td>
{{/if}}

{{#each page.custom_timing_names}}
  {{if timing.custom_timings && timing.custom_timings[$value]}}
    <td class="profiler-duration" title="aggregate number of all ${$value.toLowerCase()} invocations in this step (excludes children)">
      ${timing.custom_timings[$value].length} ${$value.toLowerCase()}
    </td>
    <td class="profiler-duration" title="aggregate duration of all ${$value.toLowerCase()} invocations in this step (excludes children)">
      ${MiniProfiler.formatDuration(timing.custom_timing_stats[$value].duration)}
    </td>
  {{else}}
    <td colspan="2"></td>
  {{/if}}
{{/each}}

</tr>

{{if timing.has_children}}
  {{#each timing.children}}
    {{tmpl({timing: $value, page: page}) "#timingTemplate"}}
  {{/each}}
{{/if}}
