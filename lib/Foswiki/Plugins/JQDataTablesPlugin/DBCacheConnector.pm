# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014-2018 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::JQDataTablesPlugin::DBCacheConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector ();
use Foswiki::Plugins::DBCachePlugin ();
use Foswiki::OopsException ();
use Foswiki::Form ();
use Foswiki::Time ();
use Foswiki::Func ();
use Foswiki::Sandbox ();
use Error qw(:try);
use JSON ();

#use Data::Dump qw(dump);

our @ISA = qw( Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector );

use constant TRACE => 0;    # toggle me

sub writeDebug {
  return unless TRACE;

  #Foswiki::Func::writeDebug("DBCacheConnector - $_[0]");
  print STDERR "DBCacheConnector - $_[0]\n";
}

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::DBCacheConnector

implements the grid connector interface using a DBCachePlugin based backend

=cut

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  # maps column names to accessors to the actual property being displayed
  $this->{propertyMap} = {
    'topic' => 'Topic',
    'Topic' => 'topic',
    'TopicTitle' => 'topictitle',
    'info.date' => 'Modified',
    'Modified' => 'info.date',
    'info.date' => 'Changed',
    'Changed' => 'info.date',
    'By' => 'info.author',
#    'Author' => 'info.author', SMELL: this may be in conflict with any formfield of that name
    'Workflow' => 'workflow.name',
    'workflow.name' => 'Workflow',
    'Created' => 'createdate',
    'createdate' => 'Created',
    'Creator' => 'createauthor',
    'creatauthor' => 'Creator',
    'CategoryTitle' => '@Category.TopicTitle'
  };

  return $this;
}

=begin TML

---++ ClassMethod buildQuery() -> $query

creates a query based on the current request

=cut

sub buildQuery {
  my ($this, $request) = @_;

  my $form = $request->param("form") || "";
  $form =~ s/\//./g;

  my @query = ();
  push @query, "form='$form'" if $form;

  my @columns = $this->getColumnsFromRequest($request);

  #print STDERR "columns=".dump(\@columns)."\n";

  # build global filter
  my $globalFilter = $request->param('search[value]');
  if (defined($globalFilter) && $globalFilter ne "") {
    my $regexFlag = ($request->param("search[regex]") || 'false') eq 'true' ? 1 : 0;

    foreach my $part (split(/\s+/, $globalFilter)) {
      $part =~ s/^\s+|\s+$//g;
      my $neg = 0;
      if ($part =~ /^-(.*)$/) {
        $part = $1;
        $neg = 1;
      }

      my @includeFilter = ();
      my @excludeFilter = ();

      foreach my $column (@columns) {
        next unless $column->{searchable};
        my $propertyName = $this->column2Property($column->{data});

        if ($neg) {
          push(@excludeFilter, "lc($propertyName)" . ($regexFlag ? "=~" : "~") . "lc('$part')");
        } else {
          push(@includeFilter, "lc($propertyName)" . ($regexFlag ? "=~" : "~") . "lc('$part')");
        }
      }

      push @query, "(" . join(" OR ", @includeFilter) . ")"
        if @includeFilter;
      push @query, "!(" . join(" OR ", @excludeFilter) . ")"
        if @excludeFilter;
    }
  }

  # build column filter
  foreach my $column (@columns) {
    next unless $column->{searchable};

    my $filter = $column->{search_value};
    next if !defined($filter) || $filter eq "";

    my $regexFlag = $column->{search_regex} eq 'true' ? 1 : 0;

    $filter = Foswiki::Plugins::JQDataTablesPlugin::Connector::urlDecode($filter);

    my $propertyName = $this->column2Property($column->{data});

    my @includeFilter = ();
    my @excludeFilter = ();

    foreach my $part (split(/\s+/, $filter)) {
      $part =~ s/^\s+|\s+$//g;

      if ($part =~ /^-(.*)$/) {
        $part = $1;
        push(@excludeFilter, "lc($propertyName)" . ($regexFlag ? "=~" : "~") . "lc('$part')");
      } else {
        push(@includeFilter, "lc($propertyName)" . ($regexFlag ? "=~" : "~") . "lc('$part')");
      }
    }

    push @query, "(" . join(" AND ", @includeFilter) . ")"
      if @includeFilter;
    push @query, "!(" . join(" AND ", @excludeFilter) . ")"
      if @excludeFilter;
  }

  push @query, $request->param("query") if $request->param("query");
  my $query = "";
  $query = join(' AND ', @query) if @query;

  writeDebug("query=$query");

  return $query;
}

=begin TML

---++ ClassMethod search( %params ) -> ($total, $totalFiltered, $data)

perform the actual search and fetch result 

=cut

sub search {
  my ($this, %params) = @_;

  my $db = Foswiki::Plugins::DBCachePlugin::getDB($params{web});
  throw Error::Simple("can't load dbcache") unless defined $db;

  my $sort = $this->column2Property($params{sort});

  my $hits = $db->dbQuery($params{query}, undef, $sort, $params{reverse});
  return (0, 0, []) unless $hits;

  my $total = scalar($db->getKeys());
  my $totalFiltered = $hits->count;
  my @data = ();

  my $index = $params{skip} ? $hits->skip($params{skip}) : 0;
  while (my $topicObj = $hits->next) {
    $index++;

    my $formName = $topicObj->fastget("form");
    $formName = $topicObj->fastget($formName) if $formName;
    $formName = $formName->fastget("name") if $formName;

    my $topic = $topicObj->fastget("topic");

    my $formDef;
    if ($formName) {

      # catch an no_form_def oops
      try {
        $formDef = new Foswiki::Form($this->{session}, $params{web}, $formName);
      }
      catch Foswiki::OopsException with {
        my $error = shift;
        print STDERR "error: $error\n";
        $formDef = undef;
      };
    }

    my %row = ();
    foreach my $fieldName (@{$params{fields}}) {
      my $propertyName = $this->column2Property($fieldName);
      next if !$propertyName || $propertyName eq '#';

      my $isEscaped = substr($fieldName, 0, 1) eq '/' ? 1 : 0;
      my $fieldDef;
      $fieldDef = $formDef->getField($propertyName) if $formDef;

      my $cell = $db->expandPath($topicObj, $propertyName);
      if (!defined($cell) || $cell eq '') {
        $cell = $fieldDef->getDefaultValue() if $fieldDef;
      }

      if (!$isEscaped && $propertyName eq 'index') {
        $cell = {
          "display" => "<span class='rowNumber'>$index</span>",
          "raw" => $index,
        };
      } elsif (!$isEscaped && $propertyName =~ /^(Date|Changed|Modified|Created|info\.date|createdate|publishdate)$/) {
        my $time = "";
        my $html = "";
        if ($cell) {
          $time = Foswiki::Time::formatTime($cell);
          $html = "<span style='white-space:nowrap'>$time</span>";
        }
        $cell = {
          "display" => $html,
          "epoch" => $cell || 0,
          "raw" => $time
        };
      } elsif (!$isEscaped && $fieldDef && $fieldDef->{type} =~ /^date/) {
        my $time = "";
        my $html = "";
        if ($cell) {
          if ($fieldDef->can("getDisplayValue") && $fieldDef->{type} ne 'date') { # standard default date formfield type can't parse&format dates
            $time = $fieldDef->getDisplayValue($cell);
          } else {
            my $epoch = ($cell =~ /^\-?\d+$/)?$cell:Foswiki::Time::parseTime($cell); 
            $time = Foswiki::Time::formatTime($epoch);
          }

          $html = "<span style='white-space:nowrap'>$time</span>";
        }
        $cell = {
          "display" => $html,
          "epoch" => $cell || 0,
          "raw" => $time,
        };
      } elsif (!$isEscaped && $propertyName eq 'topic') {
        $cell = {
          "display" => "<a href='" . Foswiki::Func::getViewUrl($params{web}, $topic) . "' style='white-space:nowrap'>$topic</a>",
          "raw" => $topic,
        };
      } elsif (!$isEscaped && $propertyName eq 'topictitle') {
        $cell = {
          "display" => "<a href='" . Foswiki::Func::getViewUrl($params{web}, $topic) . "'>$cell</a>",
          "raw" => $cell,
        };
      } elsif (!$isEscaped && $propertyName =~ /^(Author|Creator|info\.author|createauthor|publishauthor)$/) {
        my @html = ();
        foreach my $item (split(/\s*,\s*/, $cell)) {
          my $topicTitle = Foswiki::Func::getTopicTitle($Foswiki::cfg{UsersWebName}, $item);
          push @html, 
            $topicTitle eq $item ?
            $item :
            "<a href='" . Foswiki::Func::getViewUrl($Foswiki::cfg{UsersWebName}, $item) . "' style='white-space:nowrap'>$topicTitle</a>";
        }
        $cell = {
          "display" => join(", ", @html),
          "raw" => $cell || "",
        };
      } elsif (!$isEscaped && $propertyName =~ /(Image|Photo|Logo)/ && (!$fieldDef ||  $fieldDef->{type} ne 'attachment')) {
        my $url = $cell;

        unless ($url =~ /^(http:)|\//) {
          $url = Foswiki::Func::getPubUrlPath($params{web}, $topic, $cell);
        }
        $url =~ s/%PUBURLPATH%/$Foswiki::cfg{PubUrlPath}/g;

        my $html =
          $cell
          ? "<img src='$url' style='max-width:100%;max-height:5em' />"
          : "";
        $cell = {
          "display" => $html,
          "raw" => $cell || "",
        };
      } elsif (!$isEscaped && $propertyName =~ /^email$/i) {
        my $html = $cell ? "<a href='mailto:$cell'>$cell</a>" : "";
        $cell = {
          "display" => $html,
          "raw" => $cell || "",
        };
      } else {

        my $html = $cell;

        # try to render it for display
        if ($fieldDef) {

          # patch in a random field name so that they are different on each row
          # required for older JQueryPlugins
          my $oldFieldName = $fieldDef->{name};
          $fieldDef->{name} .= int(rand(10000)) + 1;

          if ($fieldDef->can("getDisplayValue")) {
            $html = $fieldDef->getDisplayValue($cell, $params{web}, $topic);
          } else {
            $html = $fieldDef->renderForDisplay('$value(display)', $cell, undef, $params{web}, $topic);
          }

          $html = Foswiki::Func::expandCommonVariables($html, $topic, $params{web});
          $html = '<noautolink> '.$html.' </noautolink>'; # SMELL: if $params{noautolink}
          $html = Foswiki::Func::renderText($html, $params{web}, $topic);

          # restore original name in form definition to prevent sideeffects
          $fieldDef->{name} = $oldFieldName;
        } else {
          $html = $this->translate($cell, $params{web}, $topic);
        }

        $cell = {
          "display" => $html,
          "raw" => $cell,
        };
      }

      $row{$fieldName} = $cell;
    }
    push @data, \%row;

    last if $params{limit} > 0 && $index >= $params{skip} + $params{limit};
  }

  return ($total, $totalFiltered, \@data);
}


1;
