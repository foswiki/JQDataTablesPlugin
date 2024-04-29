# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# JQDataTablesPlugin is Copyright (C) 2013-2024 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQDataTablesPlugin::DataTables;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Func ();
use Foswiki::Plugins ();
use Foswiki::OopsException ();
use Error qw(:try);
use JSON ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  return bless(
    $class->SUPER::new(
      $session,
      name => 'DataTables',
      version => '1.10.18',
      author => 'SpryMedia Ltd',
      homepage => 'http://datatables.net/',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
      css => ['jquery.datatables.css'],
      javascript => ['jquery.datatables.js', 'jquery.datatables.addons.js'],
      i18n => $Foswiki::cfg{SystemWebName} . "/JQDataTablesPlugin/i18n",
      dependencies => ['metadata', 'i18n', 'moment', 'pnotify'],
      summary => <<SUMMARY), $class);
!DataTables is a plug-in for the jQuery Javascript library. It is a highly
flexible tool, based upon the foundations of progressive enhancement, which
will add advanced interaction controls to any HTML table.
SUMMARY

}

sub formatHtml5Data {
  my ($this, $data) = @_;

  my @html5Data = ();

  foreach my $key (sort keys %$data) {
    next if $key =~ /^_/;

    my $val = $data->{$key};
    next unless defined $val;

    if (ref($val)) {
      $val = $this->json->encode($val);
    } else {
      $val = _entityEncode($val);
    }
    push @html5Data, "data-$key='$val'";
  }

  return join(" ", @html5Data);
}

sub json {
  my $this = shift;

  unless (defined $this->{_json}) {
    $this->{_json} = JSON->new->allow_nonref(1);
  }

  return $this->{_json};
}

sub handleEndDataTableSection {
  my $this = shift;

  return _inlineError("not inside a datatables section") unless $this->{_insideDataTableSection} > 0;

  $this->{_insideDataTableSection}--;
  return "</div>"
}

sub handleDataTableSection {
  my ($this, $session, $params, $topic, $web) = @_;

  $this->{_insideDataTableSection}++;
  $this->{session} = $session;

  my $data;
  my $error;

  try {
    $data = $this->parseParams($params, $web, $topic, 1);
  } otherwise {
    $error = shift;
    $error =~ s/ at .*$//;
  };

  return _inlineError($error) if defined $error;

  delete $data->{ajax};
  delete $data->{"server-side"};

  my $html5Data = $this->formatHtml5Data($data) // "";
  #print STDERR "html5Data=$html5Data\n";

  return "<literal><div class='$data->{_class}' $html5Data></literal>";
}

sub handleDataTable {
  my ($this, $session, $params, $topic, $web) = @_;

  $this->{session} = $session;

  my $data;
  my $error;

  try {
    $data = $this->parseParams($params, $web, $topic);
  } otherwise {
    $error = shift;
    $error =~ s/ at .*$//;
  };
  return _inlineError($error) if defined $error;

  my $width = delete $data->{_width};
  $width = defined($width) ? "width='$width'" : "";

  my $html5Data = $this->formatHtml5Data($data);

  my $result = <<"HERE";
<literal>
<literal><div class='$data->{_class}' $html5Data></literal>
<table class='foswikiTable' $width>
  <thead>$data->{_thead}</thead>
  <tbody>
  </tbody>
</table>$data->{_selectInput}
</div>
</literal>
HERE

  return $result;
}

sub parseParams {
  my ($this, $params, $web, $topic, $isSection) = @_;

  my %data = ();

  $data{_class} = "jqDataTablesContainer";
  $data{_class} .= " $params->{class}" if defined $params->{class};
  $data{_width} = $params->{width};

  my $theTopic = $params->{topic} || $topic;
  my ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($web, $theTopic);

  my $thePaging =
    Foswiki::Func::isTrue($params->{paging} || $params->{pager}, 0)
    ? 'true'
    : 'false';
  my $theScrolling =
    Foswiki::Func::isTrue($params->{scrolling} || $params->{scroller}, 0)
    ? 'true'
    : 'false';

  if ($theScrolling eq 'true') {
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesscroller");
    $data{"scroller"} = $theScrolling;
    $data{"defer-render"} = 'true';
    $data{"paging"} = 'true';
  } else {
    $data{"paging"} = $thePaging;
  }

  my $theSearching = Foswiki::Func::isTrue($params->{searching}, 0) ? 'true' : 'false';
  my $theSearchMode = $params->{searchmode} || 'global';
  $data{"searching"} = $theSearching;
  $data{"search-mode"} = $theSearchMode;

  my $theDateTimeFormat = $params->{datetimeformat};
  $data{"date-time-format"} = $theDateTimeFormat if defined $theDateTimeFormat;

  my $theSaveState = Foswiki::Func::isTrue($params->{savestate}, 0) ? 'true' : 'false';
  if ($theSaveState eq 'true') {
    $data{"state-save"} = $theSaveState;
    $data{"state-duration"} =  -1;    # use session store
  }

  my $theInfo = Foswiki::Func::isTrue($params->{info}, 0) ? 'true' : 'false';
  $data{"info"} = $theInfo;

  my $theScrollX = Foswiki::Func::isTrue($params->{scrollx}, 0) ? 'true' : 'false';
  $data{"scroll-x"} = $theScrollX;

  my $theScrollY = $params->{scrolly} || ($theScrolling eq 'true' ? 200 : "");
  $data{"scroll-y"} = $theScrollY if $theScrollY;

  my $theScrollCollapse = Foswiki::Func::isTrue($params->{scrollcollapse}, 0) ? 'true' : 'false';
  $data{"scroll-collapse"} = $theScrollCollapse;

  my $theAutoWidth = Foswiki::Func::isTrue($params->{autowidth}, 0) ? 'true' : 'false';
  $data{"auto-width"} = $theAutoWidth;

  my $theSearchDelay = $params->{searchdelay} || "1000";
  $data{"search-delay"} = $theSearchDelay;

  my $theSort = $params->{sort} || '';

  my $theLengthMenu = $params->{lengthmenu} || '';
  if ($theLengthMenu) {
    $data{"length-change"} = "true";
    $data{"length-menu"} = [map { int($_) } split(/\s*,\s*/, $theLengthMenu)];
  }

  my $thePageLength = $params->{rows} || $params->{pagelength};
  $data{"page-length"} = $thePageLength if $thePageLength;

  my $theSelecting = Foswiki::Func::isTrue($params->{selecting}, 0);
  my $theSelectMode = $params->{selectmode} || "multi";
  my $theSelectProperty = $params->{selectproperty} || "topic";
  my $theSelectName = $params->{selectname} || $theSelectProperty;
  if ($theSelecting) {
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesselect");

    my $selectOpts = {
      style => $theSelectMode,
      property => $theSelectProperty,
    };

    my $theSelection = $params->{selection};
    if (defined $theSelection && $theSelection ne "") {
      $selectOpts->{selection} = [split(/\s*,\s*/, $theSelection)];
    }

    $data{"select"} = $selectOpts;
    $data{"_selectInput"} = "<input type='hidden' name='$theSelectName' class='selectInput' />";
  } else {
    $data{"_selectInput"} = "";
  }

  my $theResponsive = Foswiki::Func::isTrue($params->{responsive}, 0);
  if ($theResponsive) {
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesresponsive");

    $data{"responsive"} = "true";
  }

  my $theFixedHeader = Foswiki::Func::isTrue($params->{fixedheader}, 0);
  if ($theFixedHeader) {
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesfixedheader");

    $data{"fixed-header"} = "true";
  }

  my $theButtons = $params->{buttons} || '';
  if ($theButtons) {
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesbuttons");
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesjszip") if $theButtons =~ /\b(excel|csv)\b/;
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablespdfmake") if $theButtons =~ /\bpdf\b/;
    my @buttons = ();
    foreach my $button (split(/\s*,\s*/, $theButtons)) {
      my $text;
      $text = "%MAKETEXT{Copy to clipboard}%" if $button eq "copy";
      $text = "%MAKETEXT{Save to CSV}%" if $button eq "csv";
      $text = "%MAKETEXT{Save to Excel}%" if $button eq "excel";
      $text = "%MAKETEXT{Save to PDF}%" if $button eq "pdf";
      $text //= $button;
      push @buttons, {
        extend => $button.($button =~ /^(copy|csv|excel|pdf)$/ ? "Html5": ""),
        text => $text,
        exportOptions => {
          columns => ":visible",
        },
      };
    }
    $data{"buttons"} = \@buttons;
  }

  my %hiddenColumns = map { $_ => 1 } split(/\s*,\s*/, $params->{hidecolumns} || '');
  my $theRowGroup = $params->{rowgroup};
  if (defined $theRowGroup && $theRowGroup ne "") {
    Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesrowgroup");
    my @rowGroup = split(/\s*,\s*/, $theRowGroup);

    $data{"row-group"} = {
      "dataSrc" => \@rowGroup
    };
  }

  my $theRowCss = $params->{rowcss};
  if (defined $theRowCss) {
    $data{"row-css"} = $theRowCss;
  }

  my $theRowClass = $params->{rowclass};
  if (defined $theRowClass) {
    $data{"row-class"} = $theRowClass;
  }

  my $theAutoColor = $params->{autocolor};
  if (defined $theAutoColor) {
    $data{"auto-color"} = $theAutoColor;
  }

  my $formDef;
  my $formParam = '';

  my $theForm = $params->{form} || '';
  if ($theForm) {
    my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName($thisWeb, $theForm);
    $formWeb =~ s/\//./g;

    $formDef = Foswiki::Form->new($this->{session}, $formWeb, $formTopic);
    $formParam = $formWeb.'.'.$formTopic;
  }

  my @columnFields = ();

  my $theCols = $params->{columns};
  if ($formDef) {
    if ($theCols) {
      foreach my $fieldName (split(/\s*,\s*/, $theCols)) {
        push @columnFields, $formDef->getField($fieldName) || $fieldName;
      }
    } else {
      @columnFields = @{$formDef->getFields()};
    }
  } else {
    if ($theCols) {
      foreach my $fieldName (split(/\s*,\s*/, $theCols)) {
        push @columnFields, $fieldName;
      }
    }
  }

  my @thead = ();

  #my @tfoot = ();
  my @multiFilter = ();
  my @columns = ();

  push @thead, "<tr>";

  my $theOrdering = Foswiki::Func::isTrue($params->{ordering}, 1);
  my $theReverse = $params->{reverse} || 'off';
  my %order = (); 
  unless ($isSection) {
    my $index = 0;
    unless (grep { my $fieldName = ref($_) ? $_->{name} : $_; $fieldName =~ /^($theSelectProperty)$/i } @columnFields) {
      push @columns,
        {
        data => $theSelectProperty,
        name => $theSelectProperty,
        visible => JSON::false,
        };
      push @thead, "<th>$theSelectProperty</th>";
      push @multiFilter, "<th></th>";
      $index++;
    }

    if ($theSelecting) {
      push @columns,
        {
        name => "null",
        data => "null",
        searchable => JSON::false,
        orderable => JSON::false,
        };
      push @thead, $theSelectMode eq 'multi' ? "<th><input type='checkbox' class='selectAll foswikiCheckbox' /></th>" : "<th></th>";
      push @multiFilter, "<th></th>";
      $index++;
    }

    foreach my $fieldDef (@columnFields) {
      my $fieldName;
      if (ref($fieldDef)) {
        $fieldName = $fieldDef->{name};
      } else {
        $fieldName = $fieldDef;
        $fieldDef = undef;
      }
      push @thead, "<th>$fieldName</th>";
      my $col = {
        "data" => $fieldName,
        "name" => $fieldName,
        "visible" => $hiddenColumns{$fieldName} ? JSON::false : JSON::true,
        "orderable" => $theOrdering ? JSON::true : JSON::false,
      };

      if ($fieldName =~ /^(index|thumbnail|icon)/) {
        $col->{render} = {
          "_" => "raw",
          "display" => "display",
        };
        $col->{title} = "";
        $col->{searchable} = JSON::false;
        $col->{orderable} = JSON::false;
      } elsif ($fieldName =~ /^(Date|Changed|Modified|Created|info\.date|createdate)$/ || ($fieldDef->{type} && $fieldDef->{type} =~ /^date/)) {
        $col->{render} = {
          "_" => "raw",
          "display" => "display",
          "sort" => "epoch",
        };
      } else {
        $col->{render} = {
          "_" => "raw",
          "display" => "display",
        };
      }

      if (!defined($col->{searchable})
        || $col->{searchable} eq JSON::true)
      {
        push @multiFilter, "<th><input type='text' class='colSearch foswikiInputField' data-column='$fieldName' /></th>";
      } else {
        push @multiFilter, "<th></th>";
      }

      # construct column title
      my $title = '';
      $title = $fieldName if $fieldName =~ s/^[#\/]//;
      my $key = $fieldName . '_title';
      $key =~ s/[_\(\)\[\]\.,\s]+/_/g;
      $title = $params->{$key} if defined $params->{$key};
      $col->{title} = $title if $title;

      my $width = $params->{$fieldName . '_width'};
      $col->{width} = $width if $width;

      push @columns, $col;

      if ($theSort =~ /\b$fieldName\b/) {
        my $reverse = 'asc';
        if ($theReverse =~ /\b$fieldName\b/) {
          $reverse = 'desc';
        } else {
          $reverse = ($theReverse =~ /^\s*(on|true|1|no)\s*$/) ? 'desc' : 'asc';
        }

        $order{$fieldName} = [$index, $reverse];
      }
      $index++;
    }
  } else {
    foreach my $fieldName (@columnFields) {
      my $col = {
        "name" => $fieldName,
        "visible" => $hiddenColumns{$fieldName} ? JSON::false : JSON::true,
        "orderable" => $theOrdering ? JSON::true : JSON::false,
      };
      my $width = $params->{$fieldName . '_width'};
      $col->{width} = $width if defined $width;
      push @columns, $col;
    }
    my $index = 0;
    foreach my $fieldName (split(/\s*,\s*/, $theSort)) {
      if ($theSort =~ /\b$fieldName\b/) {
        my $reverse = 'asc';
        if ($theReverse =~ /\b$fieldName\b/) {
          $reverse = 'desc';
        } else {
          $reverse = ($theReverse =~ /^\s*(on|true|1|no)\s*$/) ? 'desc' : 'asc';
        }

        $order{$fieldName} = [$index, $reverse];
      }
      $index++;
    }
  }
  push @thead, "</tr>";

  if ($theSearchMode eq 'multi') {
    unshift @thead, "<tr class='colSearchRow'>", @multiFilter, "</tr>";
  }

  my @order = ();
  if ($theSort eq '') {
    @order = map {$order{$_}} sort {$a->[0] <=> $b->[0]} keys %order;
  } else {
    foreach my $fieldName (split(/\s*,\s*/, $theSort)) {
      push @order, $order{$fieldName} if defined $order{$fieldName};
    }
  }

  push @order, [($theSort =~ /^\d+$/) ? $theSort : 0, ($theReverse =~ /^\s*(on|true|1|no)\s*$/) ? 'desc' : 'asc'] unless @order;    # default;

  $data{"order"} = \@order;
  $data{"_thead"} = join("\n", @thead);
  $data{"columns"} = \@columns if @columns;

  my $time = time();
  my $url = Foswiki::Func::getScriptUrl("JQDataTablesPlugin", "connector", "rest");
  my $connector =
       $params->{connector}
    || $Foswiki::cfg{JQDataTablesPlugin}{DefaultConnector}
    || 'search';

  my $theWebs = $params->{web} || $params->{webs} || $web;
  my $ajax = {
    url => $url,
    type => "post",
    data => {
      t => $time,
      form => $formParam,
      topic => "$thisWeb.$thisTopic",
      webs => $theWebs,
      connector => $connector,
    },
  };

  my $theContext = $params->{context};
  $ajax->{data}{context} = $theContext if $theContext;

  $ajax->{data}{"protected-columns"} = $params->{protectedcolumns}
    if defined $params->{protectedcolumns};

  my $theTopics = $params->{topics};
  $ajax->{data}{topics} = $theTopics if $theTopics;

  my $theInclude = $params->{include};
  $ajax->{data}{include} = $theInclude if $theInclude;

  my $theExclude = $params->{exclude};
  $ajax->{data}{exclude} = $theExclude if $theExclude;

  my $theQuery = $params->{_DEFAULT} || $params->{query} || '';
  if ($theQuery) {
    $ajax->{data}{query} = Foswiki::entityEncode($theQuery);
  }

  $data{"server-side"} = "true";
  $data{"ajax"} = $ajax;

  return \%data;
}

sub _entityEncode {
  my $text = shift;

  $text =~ s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&\$'*<=>@\]_])/'&#'.ord($1).';'/ge;
  return $text;
}

sub _inlineError {
  my $msg = shift;

  return "<span class='foswikiAlert'>Error: $msg</span>";
}


1;
