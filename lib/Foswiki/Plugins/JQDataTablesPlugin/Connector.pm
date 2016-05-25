# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014-2016 Michael Daum, http://michaeldaumconsulting.com
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
use Encode ();

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::Connector

base class for grid connectors used to feed a jqGrid widget

=cut

sub new {
    my ( $class, $session ) = @_;

    my $this = {
        session     => $session,
        propertyMap => {},
    };

    return bless( $this, $class );
}

=begin TML

---++ ClassMethod restHandleSave($request, $response)

this is called by the gridconnector REST handler based on the "oper"
url parameter as provided by the GRID widget.

=cut

sub restHandleSave {
    die "restHandleSave not implemented";
}

=begin TML

---++ ClassMethod buildQuery($request) -> $string

creates a query based on the current request

=cut

sub buildQuery {
    die "buildQuery not implemented";
}

=begin TML

---++ ClassMethod search( %params ) -> ($total, $totalFiltered, $data)

perform the actual search and fetch result 

=cut

sub search {
    die "search not implemented";
}

=begin TML

---++ ClassMethod restHandleSearch($request, $response)

this is called by the connector REST handler based on the "oper"
url parameter as provided by the Datatables widget.

=cut

sub restHandleSearch {
    my ( $this, $request, $response ) = @_;

    my $echo  = $request->param("draw")   || 0;
    my $skip  = $request->param("start")  || 0;
    my $limit = $request->param("length") || 10;
    my $web   = $request->param('web')    || $this->{session}->{webName};
    $web =
      Foswiki::Sandbox::untaint( $web, \&Foswiki::Sandbox::validateWebName );

    my $query = $this->buildQuery($request);

    my @fields  = ();
    my $sort    = "";
    my $reverse = "off";
    my $i       = 0;

    my @columns = $this->getColumnsFromRequest($request);
    foreach my $column (@columns) {
        my $fieldName = $column->{data};
        $sort = $fieldName
          if ( $request->param("order[0][column]") || 0 ) eq $i;
        $reverse = "on" if ( $request->param("order[0][dir]") || "" ) eq "desc";
        push @fields, $fieldName;
        $i++;
    }

    my $totalRecords        = 0;
    my $totalDisplayRecords = 0;
    my $data;

    ( $totalRecords, $totalDisplayRecords, $data ) = $this->search(
        web     => $web,
        query   => $query,
        sort    => $sort,
        reverse => $reverse,
        fields  => \@fields,
        limit   => $limit,
        skip    => $skip,
    );

    my $result = {
        draw            => $echo,
        recordsTotal    => $totalRecords,
        recordsFiltered => $totalDisplayRecords,
        data            => $data
    };

    $result = JSON::to_json( $result, pretty => 1 );

    $this->{session}->writeCompletePage( $result, 'view', 'application/json' );
}

=begin TML

---++ ClassMethod column2Property( $columnName ) -> $propertyName

maps a column name to the actual property in the store. 

=cut

sub column2Property {
    my ( $this, $columnName ) = @_;

    return unless defined $columnName;

    # escape column name to disambiguate property names from formfield names
    return $columnName if $columnName =~ s/^\///;

    return $this->{propertyMap}{$columnName} || $columnName;
}

=begin TML

---++ ClassMethod getColumnsFromRequest( $request ) -> @cols

read the request params and collect the column descriptions as
transmitted by the Datatables client

=cut

sub getColumnsFromRequest {
    my ( $this, $request ) = @_;

    my @columns = ();
    my @params  = $request->param();
    foreach my $key (@params) {
        next unless $key =~ /^columns\[(\d+)\]\[(.*)\]$/;
        my $index = $1;
        my $prop  = $2;
        my $val   = $request->param($key);
        $prop =~ s/[\[\]]+/_/g;

        if ( $val =~ /^(true|false)$/ ) {
            $val = $val eq 'true' ? 1 : 0;
        }

        #print STDERR "key=$key, index=$index, prop=$prop, val=$val\n";
        $columns[$index]{$prop} = $val;
    }

    return @columns;
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

1;

