(function($){"use strict";var mon=new RegExp(/\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b/i);function dateToOrd(string){string=string.replace("&nbsp;","").replace(/-/,"").replace(/^ | $/g,"");if(string===""){return 0}if(!mon.test(string)){return NaN}return new Date(string).getTime()}$.fn.dataTableExt.aTypes.unshift(function(string){if(typeof string!=="string"||isNaN(dateToOrd(string))){return null}return"date-foswiki"});$.extend($.fn.dataTableExt.oSort,{"date-foswiki-pre":function(a){var epoch=dateToOrd(a);return epoch},"date-foswiki-asc":function(a,b){return a-b},"date-foswiki-desc":function(a,b){return b-a}})})(jQuery);