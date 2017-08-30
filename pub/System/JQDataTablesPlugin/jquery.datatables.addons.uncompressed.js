/*
 * Adds a new sorting option to dataTables called <code>date-foswiki</code>.
 * Matches and sorts date strings in the format: <code>dd mmm yyyy - hh:mm</code>. For example:
 *   <ul>
 *      <li>02 Feb 1978</li>
 *      <li>17 May 2013 - 17:07</li>
 *      <li>31 Jan 2014</li>
 *   </ul>
 */

(function($) {
"use strict";

  var mon = new RegExp(/\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b/i);

  // convert to a foswiki date string to a number which we can use to sort
  function dateToOrd(string) {
    if (typeof(string) === 'number') {
      return string;
    }

    if (typeof(string) === 'string') {
      string = string.replace("&nbsp;", "").replace(/-/, "").replace(/^ | $/g, "");

      if (string === "") {
        return 0; // an empty string is an invalid Date 
      }

      if (!mon.test(string)) { // prevent simple numerics <= 12 to be detected as dates
        return NaN;
      }
    }

    return (new Date(string)).getTime();
  }

  // add auto-detection
  $.fn.dataTableExt.aTypes.unshift(
    function(string) {
      if (typeof(string) !== 'string' || isNaN(dateToOrd(string))) {
        return null;
      }
      return "date-foswiki";
    }
  );

  // define sorting
  $.extend($.fn.dataTableExt.oSort, {
    'date-foswiki-pre': function(a) {
      var epoch = dateToOrd(a);
      return epoch;
    },
    'date-foswiki-asc': function(a, b) {
      return a - b;
    },
    'date-foswiki-desc': function(a, b) {
      return b - a;
    }
  })

})(jQuery);
/*
 * Adds sorting for currencies
 */
(function($) {
"use strict";

  var re = new RegExp(/[^\$£€c\d\.\-\', ]/);

  // add auto-detection
  $.fn.dataTableExt.aTypes.unshift(
    function(data) {
      if (typeof data !== 'string' || data.indexOf(",") < 0 || re.test(data)) {
        return null;
      }

      return 'currency';
    }
  );

  // define sorting
  $.extend($.fn.dataTableExt.oSort, {
    "currency-pre": function(a) {
      if (a === '-') {
        return 0;
      }
      a = a.replace(/,-/, "").replace(/[^\d\-\.,]/g, "").replace(/,/, ".");
      return parseFloat(a, 10);
    },

    "currency-asc": function(a, b) {
      return a - b;
    },

    "currency-desc": function(a, b) {
      return b - a;
    }
  });

}(jQuery));
/*
 * Adds sorting for metrics
 * Matches numbers with an optional metric prefix
 *   <ul>
 *      <li>1 KB</li>
 *      <li>10</li>
 *      <li>1cm</li>
 *      <li>4.9GB</li>
 *   </ul>
 */
(function($) {
"use strict";

  var 
    numberReg = new RegExp(/[+-]?\d+(\.\d+)?/),
    metrix = {
      "y": 1e-24, "yocto": 1e-24,
      "z": 1e-21, "zepto": 1e-21,
      "a": 1e-18, "atto": 1e-18,
      "f": 1e-15, "femto": 1e-15,
      "p": 1e-12, "pico": 1e-12,
      "n": 1e-9, "nano": 1e-9,
      "µ": 1e-6, "micro": 1e-6,
      "m": 1e-3, "milli": 1e-3,
      "c": 1e-2, "centi": 1e-2,
      "d": 1e-1, "deci": 1e-1,
      "da": 1e1, "deka": 1e1,
      "h": 1e2, "hecto": 1e2,
      "k": 1e3, "K": 1e3, "kilo": 1e3,
      "M": 1e6, "mega": 1e6,
      "G": 1e9, "giga": 1e9,
      "T": 1e12, "tera": 1e12,
      "P": 1e15, "peta": 1e15,
      "Y": 1e24, "yotta": 1e24,
      "E": 1e18, "exa": 1e18,
      "Z": 1e21, "zetta": 1e21,
    }, 
    metrixReg = new RegExp( "[\\b\\d](" + $.map(metrix, function(val, key) { return key; }).join("|") + ")\\w+\\b", "i");

  function metricToOrd(string) {
    var match = numberReg.exec(string), num, fac;

    if (!match) {
      return NaN;
    }

    num = parseFloat(match[0], 10);
    if (isNaN(num)) {
      return NaN;
    }

    match = metrixReg.exec(string);
    if (!match) {
      return NaN;
    }

    fac = metrix[match[1]];
   
    num = num * fac;

    return num;
  }

  // add auto-detection
  $.fn.dataTableExt.aTypes.unshift(
    function(string) {
      if (isNaN(metricToOrd(string))) {
        return null;
      }
      return "metric";
    }
  );

  // define sorting
  $.extend($.fn.dataTableExt.oSort, {
    "metric-pre": function(a) {
      return metricToOrd(a);
    },

    "metric-asc": function(a, b) {
      return a - b;
    },

    "metric-desc": function(a, b) {
      return b - a;
    }
  });

}(jQuery));
'use strict';
jQuery(function($) {

  $.extend($.fn.dataTable.defaults, {
    "jQueryUI": true,
    "searching": false,
    "info": false,
    "lengthChange": false,
    "paging": false,
    "processing": true,

    //"pagingType": "full_numbers",
    "lengthMenu": [ 5, 10, 25, 50, 100 ],
    "stripeClasses": ['foswikiTableEven', 'foswikiTableOdd'],

    "language": {
      "search": "<b class='i18n' data-i18n-message='filter'>Filter:</b>",
      "info": "_START_ - _END_ of <b>_TOTAL_</b>",
      "infoEmpty": "<span class='foswikiAlert i18n' data-i18n-message='infoEmpty'>nothing found</span>",
      "infoFiltered": "",
      "lengthMenu": "<b class='i18n' data-i18n-message='lengthMenu'>Results per page:</b> _MENU_",
      "emptyTable": "<span class='i18n' data-i18n-message='emptyTable'>No data available in table</span>",
      "loadingRecords": "<span class='i18n' data-i18n-message='loadingRecords'>Loading ...</span>",
      "processing": "<span class='i18n' data-i18n-message='processing'>Processing ...</span>",
      "zeroRecords": "<span class='i18n' data-i18n-message='zeroRecords'>No matching records found</span>",
      "paginate": {
        "previous": "<span class='i18n' data-i18n-message='previous'>Previous</span>",
        "next": "<span class='i18n' data-i18n-message='next'>Next</span>"
      }
    }
  });

  var _stateDefault = 'ui-state-default',
      _sortIcon     = 'css_right ui-icon ui-icon-',
      _headerFooter = 'fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix';

  $.extend($.fn.dataTable.ext.oJUIClasses, {
      /* Full numbers paging buttons */
      "sPageButton":         "fg-button ui-button "+_stateDefault,
      "sPageButtonActive":   "ui-state-active",
      "sPageButtonDisabled": "ui-state-disabled",

      /* Features */
      "sPaging": "dataTables_paginate fg-buttonset ui-buttonset fg-buttonset-multi "+
              "ui-buttonset-multi paging_", /* Note that the type is postfixed */

      /* Sorting */
      "sSortAsc":            " sorting_asc",
      "sSortDesc":           " sorting_desc",
      "sSortable":           " sorting",
      "sSortableAsc":        " sorting_asc_disabled",
      "sSortableDesc":       " sorting_desc_disabled",
      "sSortableNone":       " sorting_disabled",
      "sSortJUIAsc":         _sortIcon+"triangle-1-n",
      "sSortJUIDesc":        _sortIcon+"triangle-1-s",
      "sSortJUI":            _sortIcon+"carat-2-n-s",
      "sSortJUIAscAllowed":  _sortIcon+"carat-1-n",
      "sSortJUIDescAllowed": _sortIcon+"carat-1-s",
      "sSortJUIWrapper":     "DataTables_sort_wrapper",
      "sSortIcon":           "DataTables_sort_icon",

      /* Scrolling */
      "sScrollHead": "dataTables_scrollHead ",
      "sScrollFoot": "dataTables_scrollFoot ",

      /* Misc */
      "sHeaderTH":  "",
      "sFooterTH":  "",
      "sJUIHeader": _headerFooter+" ui-corner-tl ui-corner-tr",
      "sJUIFooter": _headerFooter+" ui-corner-bl ui-corner-br"
  });

  $('.jqDataTablesContainer').livequery(function() {
    var $container = $(this), 
        opts = $.extend({}, $container.metadata(), $container.data());

    if (opts.scroller) {
      $.fn.dataTable.defaults.dom =
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"fr>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"i>';
    } else {
      $.fn.dataTable.defaults.dom =
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"frl>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"ip>';
    }


    if (opts.searchMode === 'multi') {
      // remove global filter filed in multi search ... is there an easier way to do this???
      opts.dom =
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"rl>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"ip>';
    }

    $container.addClass("jqDataTablesContainerInited").find("table").each(function() {
      var $table = $(this), 
          dt, 
          rowSelection = {},
          timeoutId;

      // helper to display selection info
      function drawInfo() {
        $(".dataTables_info", dt.table().container()).each(function() {
          var $this = $(this),
              num = Object.keys(rowSelection).length;

          $this.find(".select-info").remove();
          $this.append(num?"<span class='select-info'>, " + num + " selected</span>":"");
        });
      }

      // prevent it from being processed by JQTablePlugin
      $table.addClass("foswikiTableInited");

      // clean up stripes added by the server 
      $table.find(".foswikiTableEven, .foswikiTableOdd").removeClass("foswikiTableEven foswikiTableOdd");

      // clean up header links added by TablePlugin 
      $table.find("th a").each(function() {
        var $anchor = $(this),
            text = $anchor.text();
        $anchor.replaceWith(text);
      });

      // add select column
      if (typeof(opts.select) !== 'undefined') {
        opts.select.info = false; // disable default info created by Select extension

        // init row selection
        if (typeof(opts.select.selection) !== 'undefined') {
          $.each(opts.select.selection, function(i,val) {
            rowSelection[val] = true;
          });
        }

        // called per row
        opts.rowCallback = function(row, data, index) {
          var api = this.api(),
              val = data[opts.select.property],
              checkbox;

          val = typeof(val)!=='undefined'?val.raw:"";

          checkbox = $("<input />").attr({
            "type": "checkbox",
            "value": val
          });
          if (rowSelection[val]) {
            checkbox.prop("checked", true);
            api.row(index).select();
          }

          $("td:eq(0)", row).html(checkbox);
        };

        // called per page
        opts.drawCallback = function() {
          var api = this.api(),
              pageLen = api.page.len(),
              numRows = api.rows({selected:true}).nodes().length;
          $(".selectAll", api.table().container()).each(function() {
            $(this).prop("checked", pageLen === numRows);
          });
          drawInfo();
        };
      }

      // add info callback
      opts.infoCallback = function(settings, start, end, max, total, pre) {
        var num = Object.keys(rowSelection).length;
        return start +" - " + end + " of " + total + (num?"<span class='select-info'>, " + num + " selected</span>":"");
      };

      // instantiate
      dt = $table.DataTable(opts);
      //window.dt = dt; // playground

      // maintain selection state
      if (typeof(opts.select) !== 'undefined') {

        // for each row
        function selectHandler(ev, api, type, indexes) {
          var inputField = $(api.table().container()).next(),
              keys;

          api.rows(indexes).nodes().to$().each(function() {
              var $this = $(this),
                checkbox = $this.find("td:eq(0) > input"),
                val = checkbox.val(),
                isSelected = $this.is(".selected");


            if (isSelected && typeof(val) !== 'undefined') {
              rowSelection[val] = true;
            } else {
              delete rowSelection[val];
            }

            checkbox.prop('checked', isSelected);
          });

          keys = Object.keys(rowSelection).sort().join(",");
          inputField.val(keys);
          drawInfo();
        }

        dt.on("select", selectHandler);
        dt.on("deselect", selectHandler);
      }

      // remove name from pagelength select
      $(".dataTables_length select", dt.table().container()).each(function() {
        $(this).removeAttr("name");
      });

      // the select-all button
      $(".selectAll", dt.table().container()).on("change", function() {
        var $this = $(this);
        if ($this.is(":checked")) {
          dt.rows().select();
        } else {
          dt.rows().deselect();
        }
        drawInfo();
      });

      // add multi filter
      $(".colSearch", dt.table().container()).on("keyup change", function() {
        var $this = $(this),
            colSelector = $this.data("column")+":name",
            column = dt.column(colSelector),
            val = $this.val();

        if (column && column.search() !== val) {
          column.search(val);
          if (typeof(timeoutId) !== 'undefined') {
            window.clearTimeout(timeoutId);
          }
          timeoutId = window.setTimeout(function() {
            dt.draw();
          }, 400); // dunno how to access searchDelay settings
        }

        return false;
      }).on("keydown", function(ev) {
        if (ev.keyCode === 13) {
          return false;
        }
      });

      // hover behaviour
      $(document).on({
        mouseenter: function() {
          $(this).addClass("hover");
        },
        mouseleave: function() {
          $(this).removeClass("hover");
        }
      }, ".dataTable tbody > tr");


    });
  });
});
