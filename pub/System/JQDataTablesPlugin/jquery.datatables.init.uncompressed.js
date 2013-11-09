jQuery(function($) {
  "use strict";

  var defaults = {
    "bJQueryUI": true,
    "bFilter": false,
    "bInfo": false,
    "bLengthChange": false,
    "bPaginate": false,

    "sPaginationType": "full_numbers",
    "aLengthMenu": [ 5, 10, 25, 50, 100 ],
    "iDisplayLength": 10,
    "asStripeClasses": ['foswikiTableEven', 'foswikiTableOdd'],

    "oLanguage": {
      "sSearch": "<b>Search:</b>",
      "sInfo": "_START_ - _END_ of <b>_TOTAL_</b>",
      "sInfoEmpty": "<span class='foswikiAlert'>nothing found</span>",
      "sInfoFiltered": "",
      "sLengthMenu": "<b>Results per page:</b> _MENU_"
    }
  };

  $('.jqDataTablesContainer').livequery(function() {
    var $this = $(this), 
        opts = $.extend({}, defaults, $this.metadata());

    $this.addClass("jqDataTablesContainerInited").children("table").each(function() {
      var $table = $(this)

      /* clean up stripes added by the server */
      $table.find(".foswikiTableEven, .foswikiTableOdd").removeClass("foswikiTableEven foswikiTableOdd");

      /* clean up header links added by TablePlugin */
      $table.find("th a").each(function() {
        var $anchor = $(this),
            text = $anchor.text();
        $anchor.replaceWith(text);
      });

      $table.dataTable(opts);
    });
  });
});
