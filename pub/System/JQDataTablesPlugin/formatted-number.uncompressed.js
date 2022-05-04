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

