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
