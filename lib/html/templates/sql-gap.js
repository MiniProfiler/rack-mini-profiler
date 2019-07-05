<tr class="profiler-gap-info{{if g.duration < 4}} profiler-trivial-gaps{{/if}}">
  <td class="profiler-info">
    ${g.duration} <span class="profiler-unit">ms</span>
  </td>
  <td class="query">
    <div>${g.topReason.name} &mdash; ${g.topReason.duration.toFixed(2)} <span class="profiler-unit">ms</span></div>
  </td>
</tr>
