/*
 * Adds a new sorting option to dataTables called <code>date-foswiki</code>.
 * Matches and sorts date strings in the format: <code>dd mmm yyyy - hh:mm</code>. For example:
 *   <ul>
 *      <li>02 Feb 1978</li>
 *      <li>17 May 2013 - 17:07</li>
 *      <li>31 Jan 2014</li>
 *   </ul>
 */

"use strict";
(function($) {

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
/**
 * This plug-in for DataTables represents the ultimate option in extensibility
 * for sorting date / time strings correctly. It uses
 * [Moment.js](http://momentjs.com) to create automatic type detection and
 * sorting plug-ins for DataTables based on a given format. This way, DataTables
 * will automatically detect your temporal information and sort it correctly.
 *
 * For usage instructions, please see the DataTables blog
 * post that [introduces it](//datatables.net/blog/2014-12-18).
 *
 * @name Ultimate Date / Time sorting
 * @summary Sort date and time in any format using Moment.js
 * @author [Allan Jardine](//datatables.net)
 * @depends DataTables 1.10+, Moment.js 1.7+
 *
 * @example
 *    $.fn.dataTable.moment( 'HH:mm MMM D, YY' );
 *    $.fn.dataTable.moment( 'dddd, MMMM Do, YYYY' );
 *
 *    $('#example').DataTable();
 */

(function (factory) {
        if (typeof define === "function" && define.amd) {
                define(["jquery", "moment", "datatables.net"], factory);
        } else {
                factory(jQuery, moment);
        }
}(function ($, moment) {

$.fn.dataTable.moment = function ( format, locale ) {
        var types = $.fn.dataTable.ext.type;

        // Add type detection
        types.detect.unshift( function ( d ) {
                if ( d ) {
                        // Strip HTML tags and newline characters if possible
                        if ( d.replace ) {
                                d = d.replace(/(<.*?>)|(\r?\n|\r)/g, '');
                        }

                        // Strip out surrounding white space
                        d = $.trim( d );
                }

                // Null and empty values are acceptable
                if ( d === '' || d === null ) {
                        return 'moment-'+format;
                }

                var result = moment( d, format, locale, true ).isValid() ?
                        'moment-'+format:
                        null;

                //console.log((result?"YES: ":"NON: ")+"detect("+d+")="+result);
                return result;
        } );

        // Add sorting method - use an integer for the sorting
        types.order[ 'moment-'+format+'-pre' ] = function ( d ) {
                if ( d ) {
                        // Strip HTML tags and newline characters if possible
                        if ( d.replace ) {
                                d = d.replace(/(<.*?>)|(\r?\n|\r)/g, '');
                        }

                        // Strip out surrounding white space
                        d = $.trim( d );
                }
                
                return !moment(d, format, locale, true).isValid() ?
                        Infinity :
                        parseInt( moment( d, format, locale, true ).format( 'x' ), 10 );
        };
};

}));
/*
 * Adds sorting for currencies
 */
"use strict";
(function($) {

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
 * Adds formattede numbers: fetch the first float present within an html tag
 */
"use strict";
(function($) {

  var reNum = new RegExp(/^.*?<\w+.*?>\s*([+-]?\d+(\.\d+)?)?\s*<\/\w+>.*$/);

  // add auto-detection
  $.fn.dataTableExt.aTypes.unshift(
    function(data) {
      if (typeof data !== 'string' || !reNum.test(data)) {
        return null;
      }
      return 'formatted-number';
    }
  );

  // define sorting
  $.extend($.fn.dataTableExt.oSort, {
    "formatted-number-pre": function(str) {
      var a;

      a = str.replace(reNum, '$1');
      if (a === "") {
        return 0;
      }
      return parseFloat(a, 10);
    },

    "formatted-number-asc": function(a, b) {
      return a - b;
    },

    "formatted-number-desc": function(a, b) {
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
"use strict";
(function($) {

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
"use strict";
jQuery(function($) {

  var sort_prefix = 'css_right ui-icon ui-icon-',
      toolbar_prefix = 'fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-',
      _stateDefault = 'ui-state-default',
      _sortIcon     = 'css_right ui-icon ui-icon-',
      _headerFooter = 'fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix';

  $.extend($.fn.dataTable.defaults, {
    "jQueryUI": true,
    "searching": false,
    "searchDelay": 1000,
    "info": false,
    "lengthChange": false,
    "paging": false,
    "processing": true,
    "stateDuration": -1,
    "dom": 'B<"'+toolbar_prefix+'tl ui-corner-tr"lfr>'+
            't'+
            '<"'+toolbar_prefix+'bl ui-corner-br"ip>',
    renderer: 'jqueryui',

    //"pagingType": "full_numbers",
    "lengthMenu": [ 5, 10, 25, 50, 100 ],
    "stripeClasses": ['foswikiTableEven', 'foswikiTableOdd'],

    "language": {
      "search": "<b class='i18n' data-i18n-message='filter'>Filter:</b>",
      "info": "<span class='i18n' data-i18n-start='_START_' data-i18n-end='_END_' data-i18n-total='_TOTAL_'>%start% - %end% of %total%</span>",
      "infoEmpty": "",
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


  $.extend($.fn.dataTable.ext.classes, {
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

  $.fn.dataTable.ext.errMode = 'none'; // do nothing here: the server already responds with a http 500
  $.fn.dataTable.ext.renderer.header.jqueryui = function ( settings, cell, column, classes ) {

     // Calculate what the unsorted class should be
     var noSortAppliedClass = sort_prefix+'caret-2-n-s';
     var asc = $.inArray('asc', column.asSorting) !== -1;
     var desc = $.inArray('desc', column.asSorting) !== -1;

     if ( !column.bSortable || (!asc && !desc) ) {
        noSortAppliedClass = '';
     }
     else if ( asc && !desc ) {
        noSortAppliedClass = sort_prefix+'caret-1-n';
     }
     else if ( !asc && desc ) {
        noSortAppliedClass = sort_prefix+'caret-1-s';
     }

     // Setup the DOM structure
     $('<div/>')
        .addClass( 'DataTables_sort_wrapper' )
        .append( cell.contents() )
        .append( $('<span/>')
           .addClass( classes.sSortIcon+' '+noSortAppliedClass )
        )
        .appendTo( cell );

     // Attach a sort listener to update on sort
     $(settings.nTable).on( 'order.dt', function ( e, ctx, sorting, columns ) {
        if ( settings !== ctx ) {
           return;
        }

        var colIdx = column.idx;

        cell
           .removeClass( classes.sSortAsc +" "+classes.sSortDesc )
           .addClass( columns[ colIdx ] == 'asc' ?
              classes.sSortAsc : columns[ colIdx ] == 'desc' ?
                 classes.sSortDesc :
                 column.sSortingClass
           );

        cell
           .find( 'span.'+classes.sSortIcon )
           .removeClass(
              sort_prefix+'triangle-1-n' +" "+
              sort_prefix+'triangle-1-s' +" "+
              sort_prefix+'caret-2-n-s' +" "+
              sort_prefix+'caret-1-n' +" "+
              sort_prefix+'caret-1-s'
           )
           .addClass( columns[ colIdx ] == 'asc' ?
              sort_prefix+'triangle-1-n' : columns[ colIdx ] == 'desc' ?
                 sort_prefix+'triangle-1-s' :
                 noSortAppliedClass
           );
     } );
  };

  $('.jqDataTablesContainer table').livequery(function() {
    var $table = $(this),
        $container = $table.parents(".jqDataTablesContainer:first"), 
        opts = $.extend({}, $container.data(), $container.metadata()),
	rowCallbacks = [];

    // create rowCallback
    if (typeof(opts.rowCallback) !== 'undefined') {
      rowCallbacks.push(opts.rowCallback);
    }
    opts.rowCallback = function(row, data, index) {
      var self = this;
      $.each(rowCallbacks, function(i, fn) {
	fn.call(self, row, data, index);
      });
    };

    if (opts.dateTimeFormat) {
      $.fn.dataTable.moment(opts.dateTimeFormat, opts.dateTimeLocale);
    }

    if (opts.scroller) {
      $.fn.dataTable.defaults.dom =
        'B<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"fr>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"i>';
    } else {
      $.fn.dataTable.defaults.dom =
        'B<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"frl>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"ip>';
    }


    if (opts.searchMode === 'multi') {
      $container.addClass("dataTables_searchMulti");

      // remove global filter filed in multi search ... is there an easier way to do this???
      opts.dom =
        'B<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"rl>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"ip>';
    }

    $table.each(function() {
      var dt, 
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
        rowCallbacks.push(function(row, data, index) {
          var api = this.api(),
              val = data[opts.select.property],
              checkbox;

          val = typeof(val)!=='undefined'?val.raw:"";

          checkbox = $("<input />").attr({
            "type": "checkbox",
            "class": "foswikiCheckbox",
            "value": val
          });
          if (rowSelection[val]) {
            checkbox.prop("checked", true);
            api.row(index).select();
          }

          $("td:eq(0)", row).html(checkbox);
        });

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

      // row groups
      if (typeof(opts.rowGroup) !== 'undefined') {
        $.each(opts.rowGroup.dataSrc, function(i, val) {
          var num = parseInt(val, 10);
          if (!isNaN(num)) {
            opts.rowGroup.dataSrc[i] = num;
          }
        });
        /*
        opts.rowGroup.startRender = function ( rows, group ) {
          return group +' <span class="rowCount">' + rows.count()+'</span>';
        }
        */
      }

      // row css
      if (typeof(opts.rowCss) !== 'undefined') {
        var fn = new Function("data", opts.rowCss);
        rowCallbacks.push(function(row, data, index) {
          var prop = fn(data);
          if (typeof(prop) === 'string') {
            $(row).children().css("background-color", prop);
          } else if (typeof(prop) === 'object') {
            $(row).children().css(prop);
          }
        });
      }

      // row class
      if (typeof(opts.rowClass) !== 'undefined') {
        var fn = new Function("data", opts.rowClass);
        rowCallbacks.push(function(row, data, index) {
          var cls = fn(data);
          if (typeof(cls) === 'string') {
            $(row).addClass(cls);
          }
        });
      }

      // autocolor 
      if (typeof(opts.autoColor) !== 'undefined') {
        var cols = opts.autoColor.split(/\s*,\s*/);
        rowCallbacks.push(function(row, data, index) {
          var api = this.api(), index, $cells = $(row).children();
          $.each(cols, function(i, val) {
            var index = api.column(val+":name").index()-1;
            $cells.eq(index).autoColor();
          });
        });
      }

      // add error handler for ajax obj
      if (typeof(opts.ajax) !== 'undefined') {
        opts.ajax.complete = function(xhr, status, err) {
          var text;
          if (status === 'error') {
            text = xhr.responseText.replace(/ at .*/, "");
            $.pnotify({
              title: "Server Error",
              text: text,
              type: "error"
            });
          } else {
            //$.pnotify_remove_all();
          }
        };
      }

      // instantiate
      dt = $table.DataTable(opts);
      $table.data("dt", dt);

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

        dt.on("select deselect", selectHandler);
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
          }, opts.searchDelay); 
        }

        return false;
      }).on("keydown", function(ev) {
        if (ev.keyCode === 13) {
          return false;
        }
      });

      // add css class when processing data serverside
      dt.on("processing.dt", function(e, settings, processing) {
        if (processing) {
          $(dt.table().node()).addClass("processing");
        } else {
          $(dt.table().node()).removeClass("processing");
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
