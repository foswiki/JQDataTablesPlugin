# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014-2022 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::JQDataTablesPlugin::SolrConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Plugins::SolrPlugin ();
use Foswiki::OopsException ();
use Foswiki::Time ();
use Foswiki::Func ();
use Foswiki::Sandbox ();
use Error qw(:try);
use JSON ();

our @ISA = qw( Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector );

use constant TRACE => 0;    # toggle me

sub writeDebug {
  return unless TRACE;
  print STDERR "SolrConnector - $_[0]\n";
}

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::SolrConnector

implements the grid connector interface using a SolrPlugin based backend

=cut

sub new {
  my ($class, $session) = @_;

  my $this = $class->SUPER::new($session);

  # maps column names to accessors to the actual property being displayed
  $this->{columnDescription} = {
    'score' => {
      type => 'score',
      data => 'score',
      search => 'score',
      sort => 'score',
    },
    'Topic' => {
      type => 'topic',
      data => 'topic',
      search => 'topic_search',
      sort => 'topic_sort',
    },
    'TopicTitle' => {
      type => 'default',
      data => 'title',
      search => 'title_search',
      sort => 'title_sort',
    },
    'Modified' => {
      type => 'date',
      data => 'date',
      search => 'date_search',
      sort => 'date',
    },
    'Changed' => {
      type => 'date',
      data => 'date',
      search => 'date_search',
      sort => 'date',
    },
    'author' => {
      type => 'user',
      data => 'author',
      search => 'author',
      sort => 'author',
    },
    'By' => {
      type => 'user',
      data => 'author',
      search => 'author',
      sort => 'author',
    },
    'Created' => {
      type => 'date',
      data => 'createdate',
      search => 'createdate_search',
      sort => 'createdate',
    },
    'Creator' => {
      type => 'user',
      data => 'createauthor',
      search => 'createauthor',
      sort => 'createauthor',
    },

  };

  return $this;
}

=begin TML

---++ ClassMethod getColumnDescription( $columnName, $formDef ) -> $propertyName

maps a column name to the actual property in the store. 

=cut

sub getColumnDescription {
  my ($this, $columnName, $formDef) = @_;

  return unless defined $columnName;

  $columnName =~ s/^#//;

  my $desc = $this->{columnDescription}{$columnName};

  # special solr fields
  return {
    type => $columnName =~ /^(score|version|size|width|height|likes|dislikes|total_likes)$ / ? 'number': 'default',
    data => $columnName,
    search => $columnName,
    sort => $columnName,
  } if !$desc && $columnName =~ /^(index|size|width|height|language|id|url|source|type|web|topic|title|webcat|webtopic|icon|thumbnail|container_.*|summary|contributor|version|text|state|likes|dislikes|total_likes|parent|form)$/;

  my $fieldDef;
  $fieldDef = $formDef->getField($columnName) if $formDef;

  # TODO:
  # preferences. macros, attachments

  if (defined $desc) {
    unless (ref($desc)) {
      $desc = {
        type => "default",
        data => $desc,
        search => $desc,
        sort => $desc,
      };
    }
    return $desc;
  } 

  my $searcher = Foswiki::Plugins::SolrPlugin::getSearcher();
  my $dataField = $searcher->getSolrFieldNameOfFormfield($fieldDef||$columnName);
  my $fieldType = $fieldDef ? "formfield" : "default";

  my $searchField = $dataField;
  my $sortField = $dataField;

  if ($fieldDef && $fieldDef->{type} =~ /^(topic|user)/) {
    $searchField =~ s/^(.*)_(s|lst)$/$1_title_search/;
    $sortField =~ s/^(.*)_(s|lst)$/$1_title_sort/;
  } elsif ($dataField =~ /_(d|i|l|b|f)$/) {
    $searchField = $sortField = $dataField;
    $fieldType = "number";
  } elsif ($dataField =~ /_dt$/) {
    $searchField =~ s/_dt$//;
    $searchField .= '_search';
    $fieldType = "date";
  } else {
    $searchField =~ s/^(.*)_(s|lst)$/$1_search/;
    $sortField =~ s/^(.*)_(s|lst)$/$1_sort/;
  }

  #$dataField =~ s/_(lst|dt)$/_s/; # data is always _s

  $desc = {
    type => $fieldType,
    data => $dataField,
    search => $searchField,
    sort => $sortField,
  };

  #print STDERR "$columnName: type=$desc->{type}, data=$desc->{data}, search=$desc->{search}, sort=$desc->{sort}\n";
  return $desc;
}

=begin TML

---++ ClassMethod buildQuery() -> $query

creates a query based on the current request, only returns the pure string for the q parameter
of solr. any other filters are stored in $this->{_filterQuery} and used in search()

=cut

sub buildQuery {
  my ($this, $request) = @_;

  my @query = ();
  my @filterQuery = ();
  $this->{_filterQuery} = '';

  my $formDef;
  my $form = $request->param("form");
  if ($form) {
    my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName(undef, $form);
    $formWeb =~ s/\//./g;

    $formDef = $this->getForm($formWeb, $formTopic);
    writeDebug("formDef found for $form") if $formDef;
    writeDebug("formDef NOT found for $form") unless $formDef;
  } else {
    writeDebug("no form in query");
  }

  my @webs = map { my $tmp = $_; $tmp =~ s/\//./g; $tmp } split (/\s*,\s*/, $request->param("webs") || '');
  if (scalar(@webs) == 1) {
    push @filterQuery, "web:$webs[0]";
  } elsif (scalar(@webs) > 1) {
    push @filterQuery, "web:(".join(" OR ", @webs).")";
  }

  my @topics = split(/\s*,\s*/, $request->param("topics") || '');
  if (scalar(@topics) == 1) {
    push @filterQuery, "topic:$topics[0]";
  } elsif (scalar(@topics) > 1) {
    push @filterQuery, "topic:(".join(" OR ", @topics).")";
  }

  my $include = $request->param("include");
  push @filterQuery, "topic:/" . join("|", split(/\s*,\s*/, $include)) . "/" if $include;

  my $exclude = $request->param("exclude");
  push @filterQuery, "-topic:/" . join("|", split(/\s*,\s*/, $exclude)) . "/" if $exclude;

  my @columns = $this->getColumnsFromRequest($request);

  # build global filter
  my $globalFilter = $request->param('search[value]') || '';
  my $regexFlag = ($request->param("search[regex]") || 'false') eq 'true' ? 1 : 0; 

  $globalFilter =~ s/\s*$/*/ unless $regexFlag || $globalFilter eq '' || $globalFilter =~ /\b(AND|OR|NOT)\b|["']|([\*\+\~\/]\s*$)/;
  push @query, $globalFilter;

  # build column filter
  foreach my $column (@columns) {
    next unless $column->{searchable};

    my $filter = $column->{search_value};
    next if !defined($filter) || $filter eq "";

    my $regexFlag = $column->{search_regex} eq 'true' ? 1 : 0;

    $filter = Foswiki::Plugins::JQDataTablesPlugin::Connector::urlDecode($filter);

    my $neg = "";
    if ($filter =~ /^-(.*)$/) {
      $filter = $1;
      $neg = "-";
    }

    my $desc = $this->getColumnDescription($column->{data}, $formDef);
    #print STDERR "column=$column->{data}, desc->{type}=$desc->{type}, desc->{data}=$desc->{data}, desc->{search}=$desc->{search}\n";

    if ($regexFlag) {
      push @query, $neg . $desc->{search} . ':/' . $filter . '/';
    } else {
      $filter =~ s/\s*$/*/ unless 
          $filter eq '' 
          || $desc->{type} =~ /^(number|score)/ 
          || $filter =~ /\b(AND|OR|NOT)\b|["']|([\*\+\~\/]\s*$)/;

      push @query, $neg . $desc->{search} . ':(' . $filter . ')';
    }
  }

  # plain query
  push @query, $request->param("query") if $request->param("query");

  my $query = "";
  $query = join(' ', @query) if @query;
  writeDebug("query=$query");

  $this->{_filterQuery} = \@filterQuery;

  return $query;
}

=begin TML

---++ ClassMethod getValueOfResult( $doc, $property, $fieldDef ) -> $value

get a property of a result document

=cut

sub getValueOfResult {
  my ($this, $doc, $property, $fieldDef) = @_;

  my $val = join(", ", $doc->values_for($property));

#print STDERR "$property=".($val//'undef')."\n";
  return $val;
}


=begin TML

---++ ClassMethod search( %params ) -> ($total, $totalFiltered, $data)

perform the actual search and fetch result 

=cut

sub search {
  my ($this, %params) = @_;

  my $formDef;

  if ($params{form}) {
    my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName(undef, $params{form});
    $formDef = $this->getForm($formWeb, $formTopic);
  }

  my $searcher = Foswiki::Plugins::SolrPlugin::getSearcher();

  my @sort = ();
  my %isReverse = map {$_ => 1} split(/\s*,\s*/, $params{reverse});

  foreach my $s (split(/\s*,\s*/, $params{sort})) {
    my $desc = $this->getColumnDescription($s, $formDef);
    my $sort = $desc->{sort};
    if ($sort =~ /_dt$/ && !$isReverse{$s}) {
      $sort = "def($sort,999999999999999999)"; # sort empty dates last no matter what
    }
    push @sort,  $sort. " " . ($isReverse{$s} ? "desc" : "asc");
  }

  my @fl = ();
  foreach my $f (@{$params{fields}}) {
    my $desc = $this->getColumnDescription($f, $formDef); 
    push @fl, $desc->{data};
  }
  push @fl, "form", "web", "topic, score";

  my @qf = ();
  foreach my $f (@fl) {
    next if $f =~ /^(index|score|date)$/;

    if ($f =~ /^(.*)_s$/ || $f =~ /^(topic|title)$/) {
      push @qf, $1 . "_search";
    } else {
      push @qf, $f;
    }
  }

  writeDebug("qf=@qf");
  writeDebug("q=$params{query}");

  my @data = ();
  my $start = $params{skip} || 0;
  my $index = $start;
  my $totalFiltered;
  my $limit = $params{limit} || 0;
  $limit = 0 if $limit < 0;

  $searcher->iterate({
      q => $params{query},
      fq => $this->{_filterQuery},
      fl => \@fl,
      qf => \@qf,
      sort => join(", ", @sort),
      start => $start,
      limit => $limit,
    },
    sub {
      my $doc = shift;
      my $numFound = shift;

      $index++;
      $totalFiltered = $numFound unless defined $totalFiltered;

      my $row = $this->convertResult(
        fields => $params{fields}, 
        result => $doc, 
        index => $index, 
        formDef => $formDef
      );

      push @data, $row if $row;
    }
  );

  my $total = $totalFiltered;    # SMELL
  return ($total, $totalFiltered, \@data);
}

1;
