# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014-2019 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector;

use strict;
use warnings;

use Foswiki::Plugins::JQDataTablesPlugin::Connector ();
use Error qw(:try);
use Foswiki::AccessControlException ();
use Foswiki::Meta ();

our @ISA = qw( Foswiki::Plugins::JQDataTablesPlugin::Connector );

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector

base class for grid connectors that deal with foswiki topic data

=cut

=begin TML

---++ ClassMethod restHandleSave( $request, $response )

a standard save backend. it assumes that columns in a grid correspond
to formfields of a !DataForm being attached to the target topic. The 
target topic is provided via the "id" url parameter. Other url parameters
are considered to be the name of the formfield, except "id" and "oper".

=cut

sub restHandleSave {
  my ($this, $request, $response) = @_;

  #print STDERR "called restGridConnectorSave()\n";
  my @params = $request->param();

  # get the target topic
  my $web;
  my $topic;
  foreach my $key (@params) {
    next if $key eq 'oper';
    my $val = $request->param($key);

    #print STDERR "param: $key=$val\n";
    if ($key eq 'id') {
      ($web, $topic) = Foswiki::Func::normalizeWebTopicName(undef, $val);
    }
  }

  #print STDERR "web=$web, topic=$topic\n";

  # check access rights
  my $wikiName = Foswiki::Func::getWikiName();
  my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
  throw Foswiki::AccessControlException('CHANGE', $wikiName, $web, $topic, $Foswiki::Meta::reason)
    unless Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, $text, $topic, $web, $meta);

  #print STDERR "$wikiName has got change access to $web.$topic\n";

  # store formfields
  foreach my $key (@params) {
    next if $key =~ /^(id|oper)$/;
    my $val = $request->param($key);

    $val =~ s/^\s+//;
    $val =~ s/\s+$//;

    my $field = $meta->get('FIELD', $key);

    # update fields already known to the DataForm _as currently used on this topic_
    # however, a !DataForm might be instantiated in parts only. So the real check
    # would be against the !DataForm _definition_ and not only against the current
    # meta data
    if ($field) {
      $field->{value} = $val;
      $meta->putKeyed('FIELD', $field);

    } else {

      # If it is a TopicTitles that didn't find its way into a !DataForm,
      # then store it into a PREFERENCE value.
      if ($key eq 'TopicTitle') {

        # store topic title in prefs
        $meta->putKeyed(
          'PREFERENCE',
          {
            name => 'TOPICTITLE',
            title => 'TOPICTITLE',
            type => 'Local',
            value => $val,
          }
        );
      } else {
        # SMELL what about these? See comments above to better consult the
        # DataForm definition before stuffing anything into a META:FIELD.
        # Otherwise these should become META:PREFERENCEs thus removing the above
        # TopicTitle exception
        $meta->putKeyed(
          'FIELD',
          {
            name => $key,
            title => $key,
            value => $val,
          }
        );
      }
    }
  }

  # any exceptions are catched by the calling code
  Foswiki::Func::saveTopic($web, $topic, $meta, $text);
}

1;
