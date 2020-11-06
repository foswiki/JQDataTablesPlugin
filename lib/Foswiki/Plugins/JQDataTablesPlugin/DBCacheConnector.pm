# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014-2020 Michael Daum, http://michaeldaumconsulting.com
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
our @ISA = qw( Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector );

use constant TRACE => 0;    # toggle me
#use Data::Dump qw(dump);

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
  $this->{columnDescription} = {
    'Topic' => {
      type => "topic",
      data => 'topic',
      search => 'lc(topic)',
      sort => 'lc(topic)',
    },
    'TopicTitle' => {
      type => "default",
      data => 'topictitle',
      search => 'lc(topictitle)',
      sort => 'lc(topictitle)',
    },
    'Modified' => {
      type => 'date',
      data => 'info.date',
      search => 'lc(n2d(info.date))',
      sort => 'info.date',
    },
    'Changed' => {
      type => 'date',
      data => 'info.date',
      search => 'lc(n2d(info.date))',
      sort => 'info.date'
    },
    'Created' => {
      type => 'date',
      data => 'createdate',
      search => 'lc(n2d(createdate))', 
      sort => 'createdate' 
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
      data => 'createauthor',
      search => 'lc(createauthor)',
      sort => 'lc(createauthor)',
    },

    'qmstate' => 'qmstate.title',
    'qmstate_id' => 'qmstate.id',
    'qmstate_pendingApprover' => 'qmstate.pendingApprover',
    'qmstate_pendingReviewers' => 'qmstate.pendingReviewers',
    'qmstate_possibleReviewers' => 'qmstate.possibleReviewers',
    'qmstate_reviewers' => 'qmstate.reviewers',
    'qmstate_comments' => 'qmreview[comment]',

    'workflow' => 'workflow.name',
    'workflowstate' => 'workflow.name',

    'allowchange' => 'preferences.ALLOWTOPICCHANGE',
    'allowview' => 'preferences.ALLOWTOPICVIEW',
    'allowapprove' => 'preferences.ALLOWTOPICAPPROVE',
    'allowcomment' => 'preferences.ALLOWTOPICCOMMENT',
    'allowcreate' => 'preferences.ALLOWTOPICCREATE',

    'denychange' => 'preferences.DENYTOPICCHANGE',
    'denyview' => 'preferences.DENYTOPICVIEW',
    'denyapprove' => 'preferences.DENYTOPICAPPROVE',
    'denycomment' => 'preferences.DENYTOPICCOMMENT',
    'denycreate' => 'preferences.DENYTOPICCREATE',

    'comments' => {
      type => "number",
      data => 'length(comments)',
      search => 'length(comments)',
      sort => 'length(comments)',
    },
  };

  return $this;
}

=begin TML

B
---++ ClassMethod getColumnDescription( $columnName, $formDef ) -> \%desc

also consider the form definition

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
      data => $columnName,
      search => $fieldDef ? "lc(displayValue('$columnName'))" : "lc($columnName)",
      sort => $fieldDef ? "lc($columnName)" : "lc($columnName)"
    };
  }

  # be nice to WorkflowPlugin
  if ($columnName =~ /^LASTTIME_/) {
    $desc->{data} = $desc->{search} = $desc->{sort} = "workflow.$columnName";
    return $desc;
  } 

  if ($fieldDef) {

    # special handling of topic formfields
    if ($fieldDef->{type} =~ /^(cat|topic|user)/) {
      $desc->{type} = "topic";
      $desc->{search} = $desc->{sort} = "lc(\@$columnName.topictitle)";
    } 

    # special handling of date formfields
    elsif ($fieldDef->{type} =~ /^date/) {
      $desc->{type} = "date";
      $desc->{search} = "lc(n2d($columnName))";
    }
  }

  return $desc;
}

=begin TML

---++ ClassMethod buildQuery() -> $query

creates a query based on the current request

=cut

sub buildQuery {
  my ($this, $request) = @_;

  my @query = ();

  my $form = $request->param("form");
  my $formDef;

  my $context = $request->param("context");

  if ($form) {
    my ($formWeb, $formTopic) = Foswiki::Func::normalizeWebTopicName(undef, $form);
    push @query, "form='$formTopic'" unless defined $context;

    $formDef = $this->getForm($formWeb, $formTopic);
    writeDebug("formDef found for $form") if $formDef;
    writeDebug("formDef NOT found for $form") unless $formDef;
  } else {
    writeDebug("no form in query");
  }

  my @columns = $this->getColumnsFromRequest($request);

  #writeDebug("columns=".dump(\@columns));

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
        my $expr = $desc->{search} . ($regexFlag ? "=~" : "~") . "'$part'";

        if ($neg) {
          push @excludeFilter, $expr;
        } else {
          push @includeFilter, $expr;
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

      my $expr = $desc->{search} . ($regexFlag ? "=~" : "~") . "'$part'";

      if ($neg) {
        push @excludeFilter, $expr;
      } else {
        push @includeFilter, $expr;
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

---++ ClassMethod getValueOfResult( $db, $property, $fieldDef ) -> $value

get a property of a result document

=cut

sub getValueOfResult {
  my ($this, $result, $property, $fieldDef) = @_;

  # special case for form
  if ($property eq 'form') {
    my ($meta) = Foswiki::Func::readTopic($result->{obj}->fastget("web"), $result->{obj}->fastget("topic"));
    return $meta->getFormName() if defined $meta;
  }

  # use dbcache
  my $val = $result->{db}->expandPath($result->{obj}, $property);
  $val = "" if ref($val); # may return a map obj

  return $val;
}

=begin TML

---++ ClassMethod search( %params ) -> ($total, $totalFiltered, $data)

perform the actual search and fetch result 

=cut

sub search {
  my ($this, %params) = @_;

  my $formDef;
  $formDef = $this->getForm(undef $params{form}) if $params{form};

  my $sort;
  my $reverse;
  my @sort = ();
  foreach my $s (split(/\s*,\s*/, $params{sort})) {
    my $desc = $this->getColumnDescription($s, $formDef);
    push @sort, $desc->{sort} if defined $desc;
  }
  $sort = join(", ", @sort);

  my @reverse = ();
  foreach my $r (split(/\s*,\s*/, $params{reverse})) {
    my $desc = $this->getColumnDescription($r, $formDef);
    push @reverse, $desc->{sort} if defined $desc;
  }
  $reverse = join(", ", @reverse);

  my $hits;
  my $error;
  my $total = 0;

  try {
    my $core = Foswiki::Plugins::DBCachePlugin::getCore();
    foreach my $web (@{$params{webs}}) {

      my $db = Foswiki::Plugins::DBCachePlugin::getDB($web);
      next unless $db;
      $total += scalar($db->getKeys());

      # flag the current web we evaluate this query in, used by web-specific operators
      $core->currentWeb($web);

      $hits = $db->dbQuery($params{query}, $params{topics}, $sort, $reverse, $params{include}, $params{exclude}, $hits, $params{context});

      $core->currentWeb("");
    }
  } catch Error::Simple with {
    $error = shift->stringify();
    print STDERR "DBCacheConnector: ERROR - $error\n";
  };

  return (0, 0, []) unless $hits;

  my @data = ();

  my $index = $params{skip} ? $hits->skip($params{skip}) : 0;
  while (my $topicObj = $hits->next) {
    $index++;

    my $web = $topicObj->fastget("web");
    my $db = Foswiki::Plugins::DBCachePlugin::getDB($web);
    my $row = $this->convertResult(
      fields => $params{fields},
      result => {
       db => $db,
       obj => $topicObj
      }, 
      index => $index, 
      formDef => $formDef
    );

    push @data, $row if $row;
    last if $params{limit} > 0 && $index >= $params{skip} + $params{limit};
  }

  my $totalFiltered = $hits->count;

  return ($total, $totalFiltered, \@data);
}

1;
