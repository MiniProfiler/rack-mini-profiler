 <script id="profilerTemplate" type="text/x-handlebars-template">
  <div class="profiler-result">

    <div class="profiler-button {{#if has_duplicate_sql_timings}}profiler-warning{{/if}}">
    {{#if has_duplicate_sql_timings}}<span class="profiler-nuclear">!</span>{{/if}}
      <span class="profiler-number">
        {{duration}} <span class="profiler-unit">ms</span>
      </span>
      {{#if sql_count}}
      <span class="profiler-number">
        ${sql_count} <span class="profiler-unit">sql</span>
      </span>
      {{/if}}
    </div>

    <div class="profiler-popup">
      <div class="profiler-info">
        <span class="profiler-name">
          ${name} <span class="profiler-overall-duration">({{duration}} ms)</span>
        </span>
        <span class="profiler-server-time">${machine_name} on {{started}}</span>
      </div>
      <div class="profiler-output">
        <table class="profiler-timings">
          <thead>
            <tr>
              <th></th>
              <th>duration (ms)</th>
              <th class="profiler-duration-with-children">with children (ms)</th>
              <th class="time-from-start">from start (ms)</th>
            {{#if has_sql_timings}}
              <th colspan="2">query time (ms)</th>
            {{/if}}
            {{#each custom_timing_names}}
              <th colspan="2">${$value.toLowerCase()} (ms)</th>
            {{/each}}
            </tr>
          </thead>
          <tbody>
            {{tmpl({timing:root, page:this.data}) "#timingTemplate"}}
          </tbody>
          <tfoot>
            <tr>
              <td colspan="3">
                {{#if !client_timings}}
                {{tmpl "#linksTemplate"}}
                {{/if}}
                <a class="profiler-toggle-duration-with-children" title="toggles column with aggregate child durations">show time with children</a>
              </td>
            {{#if has_sql_timings}}
              <td colspan="2" class="profiler-number profiler-percent-in-sql" title="${MiniProfiler.getSqlTimingsCount(root)} queries spent ${MiniProfiler.formatDuration(duration_milliseconds_in_sql)} ms of total request time">
                ${MiniProfiler.formatDuration(duration_milliseconds_in_sql / duration_milliseconds * 100)}
                <span class="profiler-unit">% in sql</span>
              </td>
            {{/if}}
            {{#each custom_timing_names}}
              <td colspan="2" class="profiler-number profiler-percentage-in-sql" title="${custom_timing_stats[$value].count} ${$value.toLowerCase()} invocations spent ${MiniProfiler.formatDuration(custom_timing_stats[$value].duration)} ms of total request time">
                ${MiniProfiler.formatDuration(custom_timing_stats[$value].duration / duration_milliseconds * 100)}
                <span class="profiler-unit">% in ${$value.toLowerCase()}</span>
              </td>
            {{/each}}
            </tr>
          </tfoot>
        </table>
        {{#if client_timings}}
        <table class="profiler-timings profiler-client-timings">
          <thead>
            <tr>
              <th>client event</th>
              <th>duration (ms)</th>
              <th>from start (ms)</th>
            </tr>
          </thead>
          <tbody>
            {{#each MiniProfiler.getClientTimings(client_timings)}}
            <tr class="{{#if $value.isTrivial }}profiler-trivial{{/if}}">
              <td class="profiler-label">${$value.name}</td>
              <td class="profiler-duration">
                {{#if $value.duration >= 0}}
                <span class="profiler-unit"></span>${MiniProfiler.formatDuration($value.duration)}
                {{/if}}
              </td>
              <td class="profiler-duration time-from-start">
                <span class="profiler-unit">+</span>${MiniProfiler.formatDuration($value.start)}
              </td>
            </tr>
            {{/each}}
          </tbody>
          <tfoot>
            <td colspan="3">
              {{tmpl "#linksTemplate"}}
            </td>
          </tfoot>
        </table>
        {{/if}}
      </div>
    </div>

  {{#if has_sql_timings}}
    <div class="profiler-queries">
      <table>
      <thead>
        <tr>
          <th style="text-align:right">step<br />time from start<br />query type<br />duration</th>
          <th style="text-align:left">call stack<br />query</th>
        </tr>
      </thead>
      <tbody>
        {{#each(i, s) MiniProfiler.getSqlTimings(root)}}
          {{tmpl({ g:s.prevGap }) "#sqlGapTemplate"}}
          {{tmpl({ i:i, s:s }) "#sqlTimingTemplate"}}
          {{if s.nextGap}}
            {{tmpl({ g:s.nextGap }) "#sqlGapTemplate"}}
          {{/if}}
        {{/each}}
      </tbody>
      </table>
      <p class="profiler-trivial-gap-container">
        <a class="profiler-toggle-trivial-gaps">show trivial gaps</a>
      </p>
    </div>
  {{/if}}
  </div>
</script>

