var MiniProfiler = MiniProfiler || {};
MiniProfiler.list = {
    init:
        function (options) {
            var $ = MiniProfiler.jQuery;
            var opt = options || {};

            var updateGrid = function (id) {
                $.ajax({
                    url: options.path + 'results-list',
                    data: { "last-id": id },
                    dataType: 'json',
                    type: 'GET',
                    success: function (data) {
                        $('table tbody').append($("#rowTemplate").tmpl(data));
                        var oldId = id;
                        var oldData = data;
                        setTimeout(function () {
                            var newId = oldId;
                            if (oldData.length > 0) {
                                newId = oldData[oldData.length - 1].Id;
                            }
                            updateGrid(newId);
                        }, 4000);
                    }
                });
            }

            MiniProfiler.path = options.path;
            $.get(options.path + 'list.tmpl?v=' + options.version, function (data) {
                if (data) {
                    $('body').append(data);
                    $('body').append($('#tableTemplate').tmpl());
                    updateGrid();
                }
            });
        }
};
