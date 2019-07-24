(function() {
  var template = Handlebars.template, templates = Handlebars.templates = Handlebars.templates || {};
templates['request.js'] = template({"1":function(container,depth0,helpers,partials,data) {
    return "profiler-warning";
},"3":function(container,depth0,helpers,partials,data) {
    return "<span class=\"profiler-nuclear\">!</span>";
},"5":function(container,depth0,helpers,partials,data) {
    var helper;

  return "    <span class=\"profiler-number\">\n      "
    + container.escapeExpression(((helper = (helper = helpers.sql_count || (depth0 != null ? depth0.sql_count : depth0)) != null ? helper : helpers.helperMissing),(typeof helper === "function" ? helper.call(depth0 != null ? depth0 : (container.nullContext || {}),{"name":"sql_count","hash":{},"data":data}) : helper)))
    + " <span class=\"profiler-unit\">sql</span>\n    </span>\n";
},"7":function(container,depth0,helpers,partials,data) {
    return "            <th colspan=\"2\">query time (ms)</th>\n";
},"9":function(container,depth0,helpers,partials,data) {
    return "            <th colspan=\"2\">"
    + container.escapeExpression(container.lambda(depth0, depth0))
    + " (ms)</th>\n";
},"11":function(container,depth0,helpers,partials,data) {
    return "";
},"13":function(container,depth0,helpers,partials,data) {
    var helper;

  return "            <td colspan=\"2\" class=\"profiler-number profiler-percent-in-sql\" title=\"${MiniProfiler.getSqlTimingsCount(root)} queries spent ${MiniProfiler.formatDuration(duration_milliseconds_in_sql)} ms of total request time\">\n              "
    + container.escapeExpression(((helper = (helper = helpers.percent_in_sql || (depth0 != null ? depth0.percent_in_sql : depth0)) != null ? helper : helpers.helperMissing),(typeof helper === "function" ? helper.call(depth0 != null ? depth0 : (container.nullContext || {}),{"name":"percent_in_sql","hash":{},"data":data}) : helper)))
    + "\n              <span class=\"profiler-unit\">% in sql</span>\n            </td>\n";
},"15":function(container,depth0,helpers,partials,data) {
    return "            <td colspan=\"2\" class=\"profiler-number profiler-percentage-in-sql\" title=\"${custom_timing_stats[$value].count} ${$value.toLowerCase()} invocations spent ${MiniProfiler.formatDuration(custom_timing_stats[$value].duration)} ms of total request time\">\n              ${MiniProfiler.formatDuration(custom_timing_stats[$value].duration / duration_milliseconds * 100)}\n              <span class=\"profiler-unit\">% in ${$value.toLowerCase()}</span>\n            </td>\n";
},"17":function(container,depth0,helpers,partials,data) {
    var stack1;

  return "      <table class=\"profiler-timings profiler-client-timings\">\n        <thead>\n          <tr>\n            <th>client event</th>\n            <th>duration (ms)</th>\n            <th>from start (ms)</th>\n          </tr>\n        </thead>\n        <tbody>\n"
    + ((stack1 = helpers.each.call(depth0 != null ? depth0 : (container.nullContext || {}),(depth0 != null ? depth0.formatted_client_timings : depth0),{"name":"each","hash":{},"fn":container.program(18, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "        </tbody>\n        <tfoot>\n          <td colspan=\"3\">\n          </td>\n        </tfoot>\n      </table>\n";
},"18":function(container,depth0,helpers,partials,data) {
    var stack1, alias1=depth0 != null ? depth0 : (container.nullContext || {}), alias2=container.lambda, alias3=container.escapeExpression;

  return "          <tr class=\""
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.isTrivial : depth0),{"name":"if","hash":{},"fn":container.program(19, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "\">\n            <td class=\"profiler-label\">"
    + alias3(alias2((depth0 != null ? depth0.name : depth0), depth0))
    + "</td>\n            <td class=\"profiler-duration\">\n"
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.durationOverZero : depth0),{"name":"if","hash":{},"fn":container.program(21, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "            </td>\n            <td class=\"profiler-duration time-from-start\">\n              <span class=\"profiler-unit\">+</span>"
    + alias3(alias2((depth0 != null ? depth0.start : depth0), depth0))
    + "\n            </td>\n          </tr>\n";
},"19":function(container,depth0,helpers,partials,data) {
    return "profiler-trivial";
},"21":function(container,depth0,helpers,partials,data) {
    return "                <span class=\"profiler-unit\"></span>"
    + container.escapeExpression(container.lambda((depth0 != null ? depth0.duration : depth0), depth0))
    + "\n";
},"23":function(container,depth0,helpers,partials,data) {
    return "  <div class=\"profiler-queries\">\n    <table>\n    <thead>\n      <tr>\n        <th style=\"text-align:right\">step<br />time from start<br />query type<br />duration</th>\n        <th style=\"text-align:left\">call stack<br />query</th>\n      </tr>\n    </thead>\n    <tbody>\n    </tbody>\n    </table>\n    <p class=\"profiler-trivial-gap-container\">\n      <a class=\"profiler-toggle-trivial-gaps\">show trivial gaps</a>\n    </p>\n  </div>\n";
},"compiler":[7,">= 4.0.0"],"main":function(container,depth0,helpers,partials,data) {
    var stack1, helper, alias1=depth0 != null ? depth0 : (container.nullContext || {}), alias2=helpers.helperMissing, alias3="function", alias4=container.escapeExpression;

  return "<div class=\"profiler-result\">\n\n  <div class=\"profiler-button "
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.has_duplicate_sql_timings : depth0),{"name":"if","hash":{},"fn":container.program(1, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "\">\n  "
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.has_duplicate_sql_timings : depth0),{"name":"if","hash":{},"fn":container.program(3, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "\n    <span class=\"profiler-number\">\n      "
    + alias4(((helper = (helper = helpers.duration || (depth0 != null ? depth0.duration : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"duration","hash":{},"data":data}) : helper)))
    + " <span class=\"profiler-unit\">ms</span>\n    </span>\n"
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.show_total_sql_count : depth0),{"name":"if","hash":{},"fn":container.program(5, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "  </div>\n\n  <div class=\"profiler-popup\">\n    <div class=\"profiler-info\">\n      <span class=\"profiler-name\">\n        "
    + alias4(((helper = (helper = helpers.name || (depth0 != null ? depth0.name : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"name","hash":{},"data":data}) : helper)))
    + " <span class=\"profiler-overall-duration\">("
    + alias4(((helper = (helper = helpers.duration || (depth0 != null ? depth0.duration : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"duration","hash":{},"data":data}) : helper)))
    + " ms)</span>\n      </span>\n      <span class=\"profiler-server-time\">"
    + alias4(((helper = (helper = helpers.machine_name || (depth0 != null ? depth0.machine_name : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"machine_name","hash":{},"data":data}) : helper)))
    + " on "
    + alias4(((helper = (helper = helpers.started_date || (depth0 != null ? depth0.started_date : depth0)) != null ? helper : alias2),(typeof helper === alias3 ? helper.call(alias1,{"name":"started_date","hash":{},"data":data}) : helper)))
    + "</span>\n    </div>\n    <div class=\"profiler-output\">\n      <table class=\"profiler-timings\">\n        <thead>\n          <tr>\n            <th></th>\n            <th>duration (ms)</th>\n            <th class=\"profiler-duration-with-children\">with children (ms)</th>\n            <th class=\"time-from-start\">from start (ms)</th>\n"
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.has_sql_timings : depth0),{"name":"if","hash":{},"fn":container.program(7, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + ((stack1 = helpers.each.call(alias1,(depth0 != null ? depth0.formatted_custom_timing_names : depth0),{"name":"each","hash":{},"fn":container.program(9, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "          </tr>\n        </thead>\n        <tbody>\n        </tbody>\n        <tfoot>\n          <tr>\n            <td colspan=\"3\">\n"
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.hide_client_timings : depth0),{"name":"if","hash":{},"fn":container.program(11, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "              <a class=\"profiler-toggle-duration-with-children\" title=\"toggles column with aggregate child durations\">show time with children</a>\n            </td>\n"
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.has_sql_timings : depth0),{"name":"if","hash":{},"fn":container.program(13, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + ((stack1 = helpers.each.call(alias1,(depth0 != null ? depth0.custom_timing_names : depth0),{"name":"each","hash":{},"fn":container.program(15, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "          </tr>\n        </tfoot>\n      </table>\n"
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.client_timings : depth0),{"name":"if","hash":{},"fn":container.program(17, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "    </div>\n  </div>\n\n"
    + ((stack1 = helpers["if"].call(alias1,(depth0 != null ? depth0.has_sql_timings : depth0),{"name":"if","hash":{},"fn":container.program(23, data, 0),"inverse":container.noop,"data":data})) != null ? stack1 : "")
    + "</div>\n\n";
},"useData":true});
})();