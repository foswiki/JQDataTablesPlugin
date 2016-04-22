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
      "search": "<b class='i18n' data-i18n-message='Search:'>Search:</b>",
      "info": "_START_ - _END_ of <b>_TOTAL_</b>",
      "infoEmpty": "<span class='foswikiAlert i18n' data-i18n-message='nothing found'>nothing found</span>",
      "infoFiltered": "",
      "lengthMenu": "<b class='i18n' data-i18n-message='Results per page:'>Results per page:</b> _MENU_",
      "paginate": {
        "previous": "<span class='i18n' data-i18n-message='Previous'>Previous</span>",
        "next": "<span class='i18n' data-i18n-message='Next'>Next</span>"
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
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"pfr>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"il>';
    }


    if (opts.searchMode === 'multi') {
      // remove global filter filed in multi search ... is there an easier way to do this???
      opts.dom =
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-tl ui-corner-tr"pr>'+
        't'+
        '<"fg-toolbar ui-toolbar ui-widget-header ui-helper-clearfix ui-corner-bl ui-corner-br"il>';
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
