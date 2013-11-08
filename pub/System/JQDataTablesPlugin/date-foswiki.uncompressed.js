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

  // convert to a foswiki date string to a number which we can use to sort
  var dateToOrd = function (string) {
    return (new Date(string.replace(/-/, ""))).getTime();
  };

  // This will help DataTables magic detect the date format; Unshift so that it's the first data type (so it takes priority over existing)
  jQuery.fn.dataTableExt.aTypes.unshift(
    function (string) {
      if (isNaN(dateToOrd(string))) {
        return null;
      }
      return "date-foswiki";
    }
  );

  // define the sorts
  jQuery.fn.dataTableExt.oSort['date-foswiki-asc'] = function (a, b) {
    var ordA = dateToOrd(a),
        ordB = dateToOrd(b);
    return (ordA < ordB) ? -1 : ((ordA > ordB) ? 1 : 0);
  };

  jQuery.fn.dataTableExt.oSort['date-foswiki-desc'] = function (a, b) {
    var ordA = dateToOrd(a),
        ordB = dateToOrd(b);
    return (ordA < ordB) ? 1 : ((ordA > ordB) ? -1 : 0);
  };
})(jQuery);
