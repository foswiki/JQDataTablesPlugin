# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2016-2024 Michael Daum, http://michaeldaumconsulting.com
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

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::SearchConnector

implements the grid connector interface using Foswiki's standard search mechanism

=cut

use strict;
use warnings;

use Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector ();
use Foswiki::OopsException ();
use Foswiki::Time ();
use Foswiki::Func ();
use Foswiki::Sandbox ();
use Error qw(:try);
use JSON ();

our @ISA = qw( Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector );

use constant TRACE => 0;    # toggle me

=begin TML

---++ ClassMethod new($session) -> $this

constructor

=cut

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  # maps column names to accessors to the actual property being displayed
  $this->{columnDescription} = {
    'topic' => {
      type => "topic",
      data => 'name',
      search => 'name',
      sort => 'name',
    },
    'Topic' => {
      type => "topic",
      data => 'name',
      search => 'name',
      sort => 'name',
    },
    'Modified' => {
      type => 'date',
      data => 'info.date',
      search => 'info.date',
      sort => 'info.date',
    },
    'Changed' => {
      type => 'date',
      data => 'info.date',
      search => 'info.date',
      sort => 'info.date',
    },
    'Created' => {
      type => 'date',
      data => 'createinfo.date',
      search => 'createinfo.date',
      sort => 'createinfo.date',
    },
    'By' => {
      type => 'user',
      data => 'info.author',
      search => 'lc(info.author)',
      sort => 'lc(info.author)',
    },
    'author' => {
      type => 'user',
      data => 'info.author',
      search => 'lc(info.author)',
      sort => 'lc(info.author)',
     },
    'Creator' => {
      type => 'user',
      data => 'createinfo.author',
      search => 'lc(createinfo.author)',
      sort => 'lc(createinfo.author)',
     },

    #    'Workflow' => 'workflow.name',
    #    'workflow.name' => 'Workflow',
  };

  return $this;
}

=begin TML

---++ ObjectMethod getColumnDescription($columName, $formDef) -> \%desc

helper to sort on the right field

=cut

sub getColumnDescription {
  my ($this, $columnName, $formDef) = @_;

  return unless defined $columnName;

  $columnName =~ s/^#//;
  my $fieldDef;
  $fieldDef = $formDef->getField($columnName) if $formDef;

  my $desc = $this->{columnDescription}{$columnName};
  if (defined $desc) {
    unless (ref($desc)) {
      $desc = {
        type => "default",
        data => $desc,
        search => $desc,
        sort => $desc,
      };
    }
  } else {
    $desc = {
      type => $fieldDef ? "formfield" : "default",
      data => "$columnName",
      search => "lc($columnName)",
      sort => $fieldDef ? "formfield($columnName)" : $columnName,
    };
  }

  if ($fieldDef) {

    # special handling of topic formfields
    if ($fieldDef->{type} =~ /^(cat|topic|user)/) {
      $desc->{type} = "topic";
      $desc->{search} = $desc->{sort} = "lc($columnName/TopicTitle)";
    } 

    # special handling of date formfields
#   elsif ($fieldDef->{type} =~ /^date/) {
#     $desc->{type} = "date";
#     $desc->{search} = "lc(n2d($columnName))";
#   }
  }

  return $desc;
}

=begin TML

---++ ObjectMethod buildQuery() -> $query

creates a query based on the current request

=cut

sub buildQuery {
  my ($this, $request) = @_;

  my @query = ();

  my $form = $request->param("form");
  my $formDef;

  if ($form) {
    my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName(undef, $form);
    $formDef = $this->getForm($formWeb, $formTopic);

    #_writeDebug("formDef found for $form") if $formDef;
    #_writeDebug("formDef NOT found for $form") unless $formDef;
  } else {
    #_writeDebug("no form in query");
  }

  my @columns = $this->getColumnsFromRequest($request);

  #print STDERR "columns=@columns\n";

  # build global filter
  my $globalFilter = $request->param('search[value]');
  if (defined($globalFilter) && $globalFilter ne "") {
    my $regexFlag = ($request->param("search[regex]") || 'false') eq 'true' ? 1 : 0;

    foreach my $part (split(/\s+/, $globalFilter)) {
      $part =~ s/^\s+//;
      $part =~ s/\s+$//g;
      my $neg = 0;
      if ($part =~ /^-(.*)$/) {
        $part = $1;
        $neg = 1;
      }
      $part = lc($part);

      my @includeFilter = ();
      my @excludeFilter = ();

      foreach my $column (@columns) {
        next unless $column->{searchable};
        my $desc = $this->getColumnDescription($column->{data}, $formDef);
        my $expr = $desc->{search} . ($regexFlag ? "=~'$part'" : "~'*$part*'");

        if ($neg) {
          push @excludeFilter, $expr;
        } else {
          push @includeFilter, $expr;
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

    my $desc = $this->getColumnDescription($column->{data}, $formDef);
    my @includeFilter = ();
    my @excludeFilter = ();

    foreach my $part (split(/\s+/, $filter)) {
      $part =~ s/^\s+//;
      $part =~ s/\s+$//g;

      my $neg = 0;
      if ($part =~ /^-(.*)$/) {
        $part = $1;
        $neg = 1;
      }
      $part = lc($part);

      my $expr = $desc->{search} . ($regexFlag ? "=~'$part'" : "~'*$part*'");

      if ($neg) {
        push @excludeFilter, $expr;
      } else {
        push @includeFilter, $expr;
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

  _writeDebug("query=$query");

  return $query;
}

=begin TML

---++ ObjectMethod getValueOfResult( $meta, $property, $fieldDef ) -> $value

get a property of a result document

=cut

sub getValueOfResult {
  my ($this, $meta, $property, $fieldDef) = @_;

  return $meta->getFormName() if $property eq 'form';
  return Foswiki::Func::getTopicTitle($meta->web, $meta->topic, undef, $meta) if $property eq 'TopicTitle';
  return $meta->topic() if $property eq 'topic';
  return $meta->web() if $property eq 'web';

  if ($property eq "info.date") {
    my $info = $meta->getRevisionInfo();
    return $info->{date};
  }

  if ($property eq "info.author") {
    my $info = $meta->getRevisionInfo();
    return Foswiki::Func::getWikiName($info->{author});
    #return Foswiki::Func::getWikiName($info->{author}) || 'UnknownUser';
  }

  if ($property eq "createinfo.date") {
    my @info = Foswiki::Func::getRevisionInfo($meta->web, $meta->topic, 1);
    return $info[0];
  }

  if ($property eq "createinfo.author") {
    my @info = Foswiki::Func::getRevisionInfo($meta->web, $meta->topic, 1);
    return Foswiki::Func::getWikiName($info[1]);
  }

  my $field = $meta->get("FIELD", $property);
  return $field->{value} if $field && defined($field->{value}) && $field->{value} ne '';
  return $fieldDef->getDefaultValue() if $fieldDef;

  return;
}

=begin TML

---++ ObjectMethod search( %params ) -> ($total, $totalFiltered, $data)

perform the actual search and fetch result 

=cut

sub search {
  my ($this, %params) = @_;

  my $formDef;
  $formDef = $this->getForm(undef, $params{form}) if $params{form};

  my $desc = $this->getColumnDescription($params{sort}, $formDef);
  my $webs = join(", ", @{$params{webs}});

  _writeDebug("webs=$webs, reverse=$params{reverse}, sort=$desc->{sort}");
  my $hits = Foswiki::Func::query(
    $params{query},
    undef,
    {
      type => "query",
      web => $webs,
      reverse => $params{reverse},
      order => $desc->{sort},
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

    my $row = $this->convertResult(
      fields => $params{fields},
      result => $topicObj,
      index => $index, 
      formDef => $formDef
    );

    push @data, $row if $row;
    last if $params{limit} > 0 && $index >= $params{skip} + $params{limit};
  }

  return ($total, $totalFiltered, \@data);
}
sub _writeDebug {
  return unless TRACE;

  #Foswiki::Func::writeDebug("SearchConnector - $_[0]");
  print STDERR "SearchConnector - $_[0]\n";
}


1;

