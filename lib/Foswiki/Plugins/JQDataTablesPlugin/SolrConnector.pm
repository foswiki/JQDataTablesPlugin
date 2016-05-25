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

package Foswiki::Plugins::JQDataTablesPlugin::SolrConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector ();
use Foswiki::Plugins::SolrPlugin                           ();
use Foswiki::OopsException                                 ();
use Foswiki::Form                                          ();
use Foswiki::Time                                          ();
use Foswiki::Func                                          ();
use Foswiki::Sandbox                                       ();
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
    my ( $class, $session ) = @_;

    my $this = $class->SUPER::new($session);

    # maps column names to accessors to the actual property being displayed
    $this->{propertyMap} = {
        'topic'      => 'Topic',
        'Topic'      => 'topic',
        'TopicTitle' => 'title',
        'Changed'    => 'date',
        'By'         => 'author',
        'Author'     => 'author',
        'Workflow'   => 'workflow',
        'Created'    => 'createdate',
        'Creator'    => 'createauthor',
    };

    return $this;
}

=begin TML

---++ ClassMethod column2Property( $columnName ) -> $propertyName

maps a column name to the actual property in the store. 

=cut

# sub column2Property {
#   my ($this, $columnName) = @_;
#
#   my $propertyName = $this->{propertyMap}{$columnName};
#
#   unless (defined $propertyName) {
#   }
#
#   return $propertyName || $columnName;
# }

=begin TML

---++ ClassMethod property2Column( $propertyName ) -> $columnName

this strips of all solr prefixes and postfixes to get back the original formfield name

=cut

sub property2Column {
    my ( $this, $propertyName ) = @_;

    return unless defined $propertyName;

    my $columnName = $propertyName;
    $columnName =~ s/^field_//g;
    $columnName =~ s/_(?:s|search|dt|lst|f)$//g;

    return $columnName;
}

=begin TML

---++ ClassMethod buildQuery() -> $query

creates a query based on the current request

=cut

sub buildQuery {
    my ( $this, $request ) = @_;

    my @query = ();

    my $form = $request->param("form") || "";
    $form =~ s/\//./g;
    push @query, "form:'$form'" if $form;

    my $web = $request->param("web") || "";
    $web =~ s/\//./g;
    push @query, "web:$web" if $web;

    my @columns = $this->getColumnsFromRequest($request);

    # build global filter
    my $globalFilter = $request->param('search[value]') || '';
    my $regexFlag =
      ( $request->param("search[regex]") || 'false' ) eq 'true' ? 1 : 0;  # TODO

    $globalFilter =~ s/\*+$//g;
    $globalFilter .= "*";
    push @query, $globalFilter;

    # build column filter
    foreach my $column (@columns) {
        next unless $column->{searchable};
        next if $column->{data} =~ /^(?:date|createdate)$/;    # SMELL

        my $filter = $column->{search_value};
        next if !defined($filter) || $filter eq "";

        my $regexFlag = $column->{search_regex} eq 'true' ? 1 : 0;

        $filter =
          Foswiki::Plugins::JQDataTablesPlugin::Connector::urlDecode($filter);

        # TODO: this needs to add field_ and _s/_dt/_lst prefixes
        my $propertyName = $this->column2Property( $column->{data} );

        my @includeFilter = ();
        my @excludeFilter = ();

        foreach my $part ( split( /\s+/, $filter ) ) {
            $part =~ s/^\s+|\s+$//g;
            my $neg = 0;

            if ( $part =~ /^-(.*)$/ ) {
                $part = $1;
                $neg  = 1;
            }
            $part =~ s/\*+$//g;
            $part .= "*";

            if ($neg) {
                push @excludeFilter, $propertyName . ':' . $part;
            }
            else {
                push @includeFilter, $propertyName . ':' . $part;
            }
        }

        push @query, "(" . join( " AND ", @includeFilter ) . ")"
          if @includeFilter;
        push @query, "NOT (" . join( " AND ", @excludeFilter ) . ")"
          if @excludeFilter;
    }

    # plain query
    push @query, $request->param("query") if $request->param("query");

    my $query = "";
    $query = join( ' ', @query ) if @query;

    writeDebug("query=$query");

    return $query;
}

=begin TML

---++ ClassMethod search( %params ) -> ($total, $totalFiltered, $data)

perform the actual search and fetch result 

=cut

sub search {
    my ( $this, %params ) = @_;

    my $searcher = Foswiki::Plugins::SolrPlugin::getSearcher();

    my $index = $params{skip} || 0;
    my @data = ();
    my $totalFiltered;

    #my @queryFields = map {$this->column2Property($_)} @{$params{fields}};

    $searcher->iterate(
        {
            q  => $params{query},
            fl => [
                map { $this->column2Property($_) } @{ $params{fields} }, "form"
            ],
            sort => $params{sort} . ' '
              . ( $params{reverse} eq 'on' ? "desc" : "asc" ),
            start => $params{skip}  || 0,
            limit => $params{limit} || 0,
        },
        sub {
            my $doc      = shift;
            my $numFound = shift;

            $index++;

            $totalFiltered = $numFound unless defined $totalFiltered;

            my $topic    = $doc->value_for("topic");
            my $formName = $doc->value_for("form");

            #print STDERR "formName=$formName, web=$params{web}\n";

            my $formDef;
            if ($formName) {

                # catch an no_form_def oops
                try {
                    $formDef =
                      new Foswiki::Form( $this->{session}, $params{web},
                        $formName );
                }
                catch Foswiki::OopsException with {
                    my $error = shift;
                    print STDERR "error: $error\n";
                    $formDef = undef;
                };
            }

            my %row = ();

            foreach my $fieldName ( @{ $params{fields} } ) {
                my $propertyName = $this->column2Property($fieldName);    # TODO
                next if !$propertyName || $propertyName eq '#';
            
                my $isEscaped = substr($fieldName, 0, 1) eq '/' ? 1:0;

                my $cell = join( ", ", $doc->values_for($propertyName) );

                #writeDebug("fieldName=$fieldName, propertyName=$propertyName");

                if ( !$isEscaped && $propertyName eq 'index' ) {
                    $cell = {
                        "display" => "<span class='rowNumber'>$index</span>",
                        "raw"     => $index,
                    };
                }
                elsif ( !$isEscaped && $propertyName =~ /^(Date|date|createdate)$/ ) {
                    my $epoch = Foswiki::Time::parseTime($cell);
                    my $html =
                      $cell
                      ? "<span style='white-space:nowrap'>"
                      . Foswiki::Time::formatTime($epoch)
                      . "</span>"
                      : "";
                    $cell = {
                        "display" => $html,
                        "epoch"   => $epoch || 0,
                        "raw"     => Foswiki::Time::formatTime( $epoch || 0 ),
                    };
                }
                elsif ( !$isEscaped && $propertyName eq 'topic' ) {
                    $cell = {
                        "display" => "<a href='"
                          . Foswiki::Func::getViewUrl( $params{web}, $topic )
                          . "' style='white-space:nowrap'>$topic</a>",
                        "raw" => $topic,
                    };
                }
                elsif ( !$isEscaped && $propertyName eq 'title' ) {
                    $cell = {
                        "display" => "<a href='"
                          . Foswiki::Func::getViewUrl( $params{web}, $topic )
                          . "'>$cell</a>",
                        "raw" => $cell,
                    };

                    # TODO
                    # elsif author
                    # elsif image
                    # elsif email
                    # elsif score
                }
                else {

                    my $html = $cell;

                    # try to render it for display
                    my $formfieldName = $this->property2Column($fieldName);
                    my $fieldDef      = $formDef->getField($formfieldName)
                      if $formDef;

                    if ($fieldDef) {

           # patch in a random field name so that they are different on each row
           # required for older JQueryPlugins
                        my $oldFieldName = $fieldDef->{name};
                        $fieldDef->{name} .= int( rand(10000) ) + 1;

                        if ( $fieldDef->can("getDisplayValue") ) {
                            $html = $fieldDef->getDisplayValue($cell);
                        }
                        else {
                            $html =
                              $fieldDef->renderForDisplay( '$value(display)',
                                $cell, undef, $params{web}, $topic );
                        }
                        $html =
                          Foswiki::Func::expandCommonVariables( $html, $topic,
                            $params{web} );

               # restore original name in form definition to prevent sideeffects
                        $fieldDef->{name} = $oldFieldName;
                    }

                    $cell = {
                        "display" => $html,
                        "raw"     => $cell,
                    };
                }
                $row{$fieldName} = $cell;
            }
            push @data, \%row;
        }
    );

    my $total = $totalFiltered;    # SMELL
    return ( $total, $totalFiltered, \@data );
}

1;
