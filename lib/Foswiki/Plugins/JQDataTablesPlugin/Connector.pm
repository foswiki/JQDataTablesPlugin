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

package Foswiki::Plugins::JQDataTablesPlugin::Connector;

use strict;
use warnings;

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::Connector

base class for grid connectors used to feed a jqGrid widget

=cut

sub new {
  my ($class, $session) = @_;

  my $this = {
    session => $session,
    columnDescription => {},
  };

  return bless($this, $class);
}

=begin TML

---++ ClassMethod restHandleSave($request, $response)

this is called by the gridconnector REST handler based on the "oper"
url parameter as provided by the GRID widget.

=cut

sub restHandleSave {
  die "not implemented";
}

=begin TML

---++ ClassMethod buildQuery($request) -> $string

creates a query based on the current request

=cut

sub buildQuery {
  die "not implemented";
}


=begin TML

---++ ClassMethod convertResult( %params ) -> \%rows

convert a result to a rows for datatable.

params:

   * fields: list of fields to extract
   * result: result object (e.g. a solr document)
   * index: row number of the result being rendered
   * formDef (optional): form definition of all items in the result set

=cut

sub convertResult {
  die "not implemented";
}

=begin TML

---++ ClassMethod getValueOfResult( $doc, $property, $fieldDef ) -> $value

get a property of a result document

=cut

sub getValueOfResult {
  die "not implemented";
}


=begin TML

---++ ClassMethod search( %params ) -> ($total, $totalFiltered, $data)

perform the actual search and fetch result 

=cut

sub search {
  die "not implemented";
}

=begin TML

---++ ClassMethod restHandleSearch($request, $response)

this is called by the connector REST handler based on the "oper"
url parameter as provided by the Datatables widget.

=cut

sub restHandleSearch {
  my ($this, $request, $response) = @_;

  my $echo = $request->param("draw") || 0;
  my $skip = $request->param("start") || 0;
  my $limit = $request->param("length") || 10;
  my $form = $request->param("form");
  my $web = $request->param("web") || $this->{session}{webName};
  my $topic = $request->param("topic") || $this->{session}{topicName};
  my $webs = $request->param("webs");
  my $context = $request->param("context");

  ($web, $topic) = Foswiki::Func::normalizeWebTopicName($web, $topic);

  my @webs;
  if ($webs) {
    if ($webs eq 'all') {
      @webs = Foswiki::Func::getListOfWebs();
    } else {
      @webs = split(/\s*,\s*/, $webs);
    }
  } else {
    push @webs, $web;
  }

  my $topics = $request->param("topics");
  $topics = [split(/\s*,\s*/, $topics)] if $topics;

  my $include = $request->param("include") // '';
  my $exclude = $request->param("exclude") // '';

  $this->{_protectedColumns} = {map {$_ => 1} split(/\s*,\s*/, $request->param("protected-columns") // '')};

  my $query = $this->buildQuery($request);

  my @fields = ();
  my @reverse = ();

  my @columns = $this->getColumnsFromRequest($request);
  foreach my $column (@columns) {
    my $fieldName = $column->{name};
    push @fields, $fieldName;
    push @reverse, $fieldName if $column->{_reverse};
    #print STDERR "fieldName=$fieldName, searchable=".($column->{searchable}//'undef').",sorted=".($column->{_sorted}//'undef').", reverse=".($column->{_reverse}//'undef')."\n";
  }

  my @sort = map {$_->{name}} sort {$a->{_sorted} <=> $b->{_sorted}} grep {defined $_->{_sorted}} @columns;

  my ($totalRecords, $totalDisplayRecords, $data) = $this->search(
    web => $web,
    topic => $topic,
    webs => \@webs,
    topics => $topics,
    include => $include,
    exclude => $exclude,
    query => $query,
    sort => join(", ", @sort),
    reverse => join(", ", @reverse),
    fields => \@fields,
    limit => $limit,
    skip => $skip,
    form => $form,
    context => $context,
  );

  my $result = {
    draw => $echo,
    recordsTotal => $totalRecords // 0,
    recordsFiltered => $totalDisplayRecords // 0,
    data => $data
  };

  $result = JSON::to_json($result, pretty => 1);

  $this->{session}->writeCompletePage($result, 'view', 'application/json');
}

=begin TML

---++ ClassMethod getColumnDescription( $columnName, $formDef ) -> \%desc

describe the kind of data for a column as available in the store. this returns
a description has 

{
  type => "date|user|topic|formfield|default|image|icon|email|index|score|number", 
  data => "...", # access to the raw data
  search => "...", # data that is being searched for
  sort => "...", # data in a sortable fashion
}

=cut

sub getColumnDescription {
  my ($this, $columnName, $formDef) = @_;

  return unless defined $columnName;
  my $desc;

  # escape column name to disambiguate property names from formfield names
  if ($columnName =~ /^\/(.*)$/) {
    $desc = $1;
  } else {
    $columnName =~ s/^#//;
    my $desc = $this->{columnDescription}{$columnName};
    return unless defined $desc;
  }

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

=begin TML

---++ ClassMethod getColumnsFromRequest( $request ) -> @cols

read the request params and collect the column descriptions as
transmitted by the Datatables client

=cut

#use Data::Dump qw(dump);
sub getColumnsFromRequest {
  my ($this, $request) = @_;

  my @columns = ();
  my @order = ();
  my @params = $request->param();

  foreach my $key (@params) {
    next unless $key =~ /^(columns|order)\[(\d+)\]\[(.*)\]$/;
    my $type = $1;
    my $index = $2;
    my $prop = $3;
    $prop =~ s/[\[\]]+/_/g;

    my $val = $request->param($key);

    if ($val =~ /^(true|false)$/) {
      $val = $val eq 'true' ? 1 : 0;
    }

    #print STDERR "key=$key, index=$index, prop=$prop, val=$val\n";

    if ($type eq 'columns') {
      $columns[$index]{$prop} = $val;
    } else {
      $order[$index]{$prop} = $val;
    }
  }

  my $index = 1;
  foreach my $order (@order) {
    my $col = $order->{column};
    $columns[$col]{_sorted} = $index++;
    $columns[$col]{_reverse} = $order->{dir} eq 'desc' ? 1 : 0;
  }

  #print STDERR dump(\@columns) . "\n";
  #print STDERR dump(\@order) . "\n";

  return @columns;
}

=begin TML

---++ ClassMethod translate($string, $web, $topic) -> $string

translate string to user's current language

=cut

sub translate {
  my ($this, $string, $web, $topic) = @_;

  return $string if $string =~ /^<\w+ /; # don't translate html code

  my $result = $string;

  $string =~ s/^_+//;    # strip leading underscore as maketext doesnt like it

  my $context = Foswiki::Func::getContext();
  if ($context->{'MultiLingualPluginEnabled'}) {
    require Foswiki::Plugins::MultiLingualPlugin;
    $result = Foswiki::Plugins::MultiLingualPlugin::translate($string, $web, $topic);
  } else {
    $result = $this->{session}->i18n->maketext($string);
  }

  $result //= $string;

  return $result;
}

=begin TML

---++ StaticMethod urlDecode( $text ) -> $text

from Fowiki.pm

=cut

sub urlDecode {
  my $text = shift;
  $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;
  return $text;
}

=begin TML

---++ ClassMethod isValueMapped( $fieldDef ) -> $boolean

should be in FieldDefinition

=cut

sub isValueMapped {
  my ($this, $fieldDef) = @_;

  return $fieldDef ? $fieldDef->can("isValueMapped") ? $fieldDef->isValueMapped() : $fieldDef->{type} =~ /\+values/ : 0;
}

=begin TML

---++ ClassMethod isProtected( $colname ) -> $boolean

returns true if the column is supposed to be be protected

=cut

sub isProtected {
  my ($this, $colName) = @_;

  return exists $this->{_protectedColumns}{$colName} ? 1:0;
}

1;

