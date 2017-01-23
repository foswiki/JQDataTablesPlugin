# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2016-2017 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::JQDataTablesPlugin::SearchConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector ();
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

  #Foswiki::Func::writeDebug("SearchConnector - $_[0]");
  print STDERR "SearchConnector - $_[0]\n";
}

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::SearchConnector

implements the grid connector interface using Foswiki's standard search mechanism

=cut

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  # maps column names to accessors to the actual property being displayed
  $this->{propertyMap} = {
    'Topic' => 'name',
    'Modified' => 'info.date',
    'Changed' => 'info.date',
    'By' => 'info.author',
    'Author' => 'info.author',
    'Created' => 'createinfo.date',
    'Creator' => 'createinfo.author',

    #    'Workflow' => 'workflow.name',
    #    'workflow.name' => 'Workflow',
  };

  # maps column names to accessors appropriate for sorting
  $this->{sortPropertyMap} = {
    'Topic' => 'topic',
    'Modified' => 'modified',
    'Changed' => 'modified',
    'By' => 'editby',
    'Author' => 'editby'
  };

  return $this;
}

=begin TML

---++ ClassMethod column2SortProperty() -> $string

helper to sort on the right field

=cut

sub column2SortProperty {
  my ($this, $column) = @_;

  return $this->{sortPropertyMap}{$column} || "formfield($column)";
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
          push(@excludeFilter, "lc($propertyName)" . ($regexFlag ? "=~lc('$part')" : "~lc('*$part*')"));
        } else {
          push(@includeFilter, "lc($propertyName)" . ($regexFlag ? "=~lc('$part')" : "~lc('*$part*')"));
        }
      }

      push @query, "(" . join(" OR ", @includeFilter) . ")"
        if @includeFilter;
      push @query, "NOT (" . join(" OR ", @excludeFilter) . ")"
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
        push(@excludeFilter, "lc($propertyName)" . ($regexFlag ? "=~lc('$part')" : "~lc('*$part*')"));
      } else {
        push(@includeFilter, "lc($propertyName)" . ($regexFlag ? "=~lc('$part')" : "~lc('*$part*')"));
      }

    }

    push @query, "(" . join(" AND ", @includeFilter) . ")"
      if @includeFilter;
    push @query, "NOT (" . join(" AND ", @excludeFilter) . ")"
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

  my @result = ();

  my $sort = $this->column2SortProperty($params{sort});
  my $hits = Foswiki::Func::query(
    $params{query},
    undef,
    {
      type => "query",
      web => $params{web},
      reverse => $params{reverse},
      order => $sort,
      files_without_match => 1,    # SMELL: try this
    }
  );
  return (0, 0, ()) unless $hits;

  my $total = $hits->numberOfTopics;
  my $totalFiltered = $total;      # SMELL: ???
  my @data = ();

  # SMELL: can't run ->skip() as this does not respect filters
  #my $index = $params{skip} ? $hits->skip($params{skip}): 0;
  my $index = 0;
  while ($hits->hasNext) {
    my $webtopic = $hits->next;
    $index++;
    next if $index <= $params{skip};    # SMELL: this is slow, see above

    my ($web, $topic) = Foswiki::Func::normalizeWebTopicName('', $webtopic);
    my ($topicObj) = Foswiki::Func::readTopic($web, $topic);

    my $formName = $topicObj->getFormName();
    my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName($web, $formName);

    my $formDef;
    if ($formName) {

      # catch an no_form_def oops
      try {
        $formDef = new Foswiki::Form($this->{session}, $formWeb, $formTopic);
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

      my $cell;

      if (!$isEscaped && $propertyName eq 'index') {
        $cell = {
          "display" => "<span class='rowNumber'>$index</span>",
          "raw" => $index,
        };
      } elsif (!$isEscaped && $propertyName eq "info.date") {
        my $info = $topicObj->getRevisionInfo();
        my $date = Foswiki::Time::formatTime($info->{date} || 0);
        my $html = "<span style='white-space:nowrap'>" . $date . "</span>";
        $cell = {
          "display" => $html,
          "epoch" => $info->{date} || 0,
          "raw" => $date,
        };
      } elsif (!$isEscaped && $propertyName eq "createinfo.date") {
        my @info = Foswiki::Func::getRevisionInfo($web, $topic, 1);
        my $date = Foswiki::Time::formatTime($info[0] || 0);
        my $html = "<span style='white-space:nowrap'>" . $date . "</span>";
        $cell = {
          "display" => $html,
          "epoch" => $info[0] || 0,
          "raw" => $date,
        };
      } elsif (!$isEscaped && $propertyName eq 'name') {
        $cell = {
          "display" => "<a href='" . Foswiki::Func::getViewUrl($web, $topic) . "' style='white-space:nowrap'>$topic</a>",
          "raw" => $topic,
        };
      } elsif (!$isEscaped && $propertyName eq 'TopicTitle') {
        my $topicTitle = $this->getTopicTitle($web, $topic, $topicObj);
        $cell = {
          "display" => "<a href='" . Foswiki::Func::getViewUrl($web, $topic) . "'>$topicTitle</a>",
          "raw" => $topicTitle,
        };
      } elsif (!$isEscaped && $propertyName eq "wikiname") {
        my $info = $topicObj->getRevisionInfo();
        my $author = Foswiki::Func::getWikiName($info->{author}) || '';
        my $topicTitle = $this->getTopicTitle($Foswiki::cfg{UsersWebName}, $author, $topicObj);
        my $html = "<a href='" . Foswiki::Func::getViewUrl($Foswiki::cfg{UsersWebName}, $author) . "' style='white-space:nowrap'>$topicTitle</a>";
        $cell = {
          "display" => $html,
          "raw" => $author,
        };
      } elsif (!$isEscaped && $propertyName eq "createinfo.author") {
        my @info = Foswiki::Func::getRevisionInfo($web, $topic, 1);
        my $author = $info[1] || '';
        my $topicTitle = $this->getTopicTitle($Foswiki::cfg{UsersWebName}, $author, $topicObj);
        my $html = "<a href='" . Foswiki::Func::getViewUrl($Foswiki::cfg{UsersWebName}, $author) . "' style='white-space:nowrap'>$topicTitle</a>";
        $cell = {
          "display" => $html,
          "raw" => $author,
        };
      } elsif (!$isEscaped && $propertyName =~ /(Image|Photo|Logo)/) {
        $cell = $topicObj->get('FIELD', $propertyName);
        $cell = $cell->{value} if defined $cell;
        my $url = $cell;
        unless ($url =~ /^(http:)|\//) {
          $url = Foswiki::Func::getPubUrlPath($web, $topic, $cell);
        }
        $url =~ s/%PUBURLPATH%/$Foswiki::cfg{PubUrlPath}/g;

        #$url =~ s/^https?://g;
        my $html =
          $cell
          ? "<img src='$url' style='max-width:100%;max-height:5em' />"
          : "";
        $cell = {
          "display" => $html,
          "raw" => $cell || "",
        };
      } elsif (!$isEscaped && $propertyName =~ /^email$/i) {
        $cell = $topicObj->get('FIELD', $propertyName);
        $cell = $cell->{value} if defined $cell;
        my $html = $cell ? "<a href='mailto:$cell'>$cell</a>" : "";
        $cell = {
          "display" => $html,
          "raw" => $cell || "",
        };
      } else {

        $cell = $topicObj->get('FIELD', $propertyName);
        $cell = $cell->{value} if defined $cell;

        my $html = $cell;

        # try to render it for display
        my $fieldDef = $formDef->getField($propertyName) if $formDef;

        if ($fieldDef) {

          # patch in a random field name so that they are different on each row
          # required for older JQueryPlugins
          my $oldFieldName = $fieldDef->{name};
          $fieldDef->{name} .= int(rand(10000)) + 1;

          if ($fieldDef->can("getDisplayValue")) {
            $html = $fieldDef->getDisplayValue($cell);
          } else {
            $html = $fieldDef->renderForDisplay('$value(display)', $cell, undef, $web, $topic);
          }
          $html = Foswiki::Func::expandCommonVariables($html, $topic, $web);

          # restore original name in form definition to prevent sideeffects
          $fieldDef->{name} = $oldFieldName;
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

