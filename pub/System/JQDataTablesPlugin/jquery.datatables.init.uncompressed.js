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
    "info": false,
    "lengthChange": false,
    "paging": false,
    "processing": true,
    "stateDuration": -1,
    "dom": '<"'+toolbar_prefix+'tl ui-corner-tr"lfr>'+
            't'+
            '<"'+toolbar_prefix+'bl ui-corner-br"ip>',
    renderer: 'jqueryui',

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

  $('.jqDataTablesContainer').livequery(function() {
    var $container = $(this), 
        opts = $.extend({}, $container.metadata(), $container.data()),
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
        rowCallbacks.push(function(row, data, index) {
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

      // add info callback
      opts.infoCallback = function(settings, start, end, max, total, pre) {
        var num = Object.keys(rowSelection).length;
        return start +" - " + end + " of " + total + (num?"<span class='select-info'>, " + num + " selected</span>":"");
      };

      // row groups
      if (typeof(opts.rowGroup) !== 'undefined') {
        $.each(opts.rowGroup.dataSrc, function(i, val) {
          var num = parseInt(val, 10);
          if (!isNaN(num)) {
            opts.rowGroup.dataSrc[i] = num;
          }
        });
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
