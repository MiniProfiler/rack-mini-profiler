<a href="${MiniProfiler.shareUrl(id)}" class="profiler-share-profiler-results" target="_blank">share</a>
<a href="${MiniProfiler.moreUrl()}" class="profiler-more-actions">more</a>
{{#if custom_link}}
<a href="${custom_link}" class="profiler-custom-link" target="_blank">${custom_link_name}</a>
{{/if}}
{{#if has_trivial_timings}}
<a class="profiler-toggle-trivial" data-show-on-load="${has_all_trivial_timings}" title="toggles any rows with &lt; ${trivial_duration_threshold_milliseconds} ms">
  show trivial
</a>
{{/if}}
