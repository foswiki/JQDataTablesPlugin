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
