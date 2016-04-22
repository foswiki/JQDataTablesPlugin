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
    string = string.replace("&nbsp;", "").replace(/-/, "").replace(/^ | $/g, "");

    if (string === "") {
      return 0; // an empty string is an invalid Date 
    }

    if (!mon.test(string)) { // prevent simple numerics <= 12 to be detected as dates
      return NaN;
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
