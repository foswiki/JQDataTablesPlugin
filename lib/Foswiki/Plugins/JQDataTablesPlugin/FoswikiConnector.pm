# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2014-2024 Michael Daum, http://michaeldaumconsulting.com
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

=begin TML

---+ package Foswiki::Plugins::JQDataTablesPlugin::FoswikiConnector

base class for grid connectors that deal with foswiki topic data

=cut

use strict;
use warnings;

use Foswiki::Plugins::JQDataTablesPlugin::Connector ();
use Error qw(:try);
use Foswiki::AccessControlException ();
use Foswiki::Meta ();
use Foswiki::Form ();

our @ISA = qw( Foswiki::Plugins::JQDataTablesPlugin::Connector );

=begin TML

---++ ObjectMethod restHandleSave( $request, $response )

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

=begin TML

sub getForm($web, $topic) -> $formDef

returns a Foswiki::Form for the given web.topic address;
may return undef when the form does not exist

=cut

sub getForm {
  my ($this, $web, $topic) = @_;

  return unless $web && $topic;

  my $formDef;

  try {
    $formDef = Foswiki::Form->new($this->{session}, $web, $topic);
  } catch Error with {
    # nope
  };

  return $formDef;
}

=begin TML

---++ ObjectMethod convertResult( %params ) -> \%row

convert a result to a rows for datatable.

This implementation may be shared among all connectors that deal with foswiki data.

=cut

sub convertResult {
  my ($this, %params) = @_;

  my %row = ();
  my $formDef = $params{formDef};

  my $wikiName = Foswiki::Func::getWikiName();

  my $count = 0;
  foreach my $fieldName (@{$params{fields}}) {

    my $web = $this->getValueOfResult($params{result}, "web");
    my $topic = $this->getValueOfResult($params{result}, "topic");
    my $isEscaped = substr($fieldName, 0, 1) eq '/' ? 1 : 0;
    my $isLinked = substr($fieldName, 0, 1) eq '#' ? 1 : 0;
    my $hasWriteAccess;

    unless ($formDef) {
      my $form = $this->getValueOfResult($params{result}, "form");
      $formDef = $this->getForm($web, $form);
    }

    my $desc = $this->getColumnDescription($fieldName, $formDef);
    next if !$desc || $desc->{data} eq '#';

    $isLinked = 1 if $desc->{data} eq 'TopicTitle' || $fieldName eq 'TopicTitle'; # backwards compatibility

    my $fieldDef;
    $fieldDef = $formDef->getField($fieldName) || $formDef->getField($desc->{data}) if $formDef;

    my $fieldValue = join(", ", $this->getValueOfResult($params{result}, $desc->{data}, $fieldDef));
    #print STDERR "fieldName=$fieldName, desc=$desc->{data}, fieldValue=$fieldValue\n";

    #print STDERR "$fieldName is protected\n" if $this->isProtected($fieldName);

    # generate cell based on column type
    my $cell;

    if ($this->isProtected($fieldName)) {
      unless (defined $hasWriteAccess) {
        my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
        $hasWriteAccess = Foswiki::Func::checkAccessPermission('CHANGE', $wikiName, $text, $topic, $web, $meta) ? 1 : 0
      }
      unless ($hasWriteAccess) {
        $cell = {
          "display" => '***',
          "raw" => '***',
        };
      }
    } 

    if (defined $cell) {
      # nop
    } elsif ($fieldName eq 'index' || $desc->{type} eq 'index') {
      $cell = {
        "display" => "<span class='rowNumber'>$params{index}</span>",
        "raw" => $params{index},
      };
    } elsif ($fieldName eq 'score' || $desc->{type} eq 'score') {
      my $score = $this->getValueOfResult($params{result}, $desc->{data}) || 0;
      $cell = {
        "display" => sprintf('%.02f', $score),
        "raw" => $score,
      };
    } elsif ($desc->{type} eq 'percent') {
      my $value = $this->getValueOfResult($params{result}, $desc->{data}) || 0;
      $cell = {
        "display" => sprintf('%.02f%%', $value),
        "raw" => $value,
      };
    } elsif (!$isEscaped && (
        $fieldName =~ /^(Date|Changed|Modified|Created|date|createdate)$/ 
        || ($fieldDef && $fieldDef->{type} =~ /^date/) 
        || $desc->{type} eq 'date'
      )) {
      my $time = "";
      my $html = "";
      my $epoch;
      if ($fieldValue) {
        $epoch = ($fieldValue =~ /^\-?\d+$/) ? $fieldValue : Foswiki::Time::parseTime($fieldValue);
        if ($fieldDef && $fieldDef->can("getDisplayValue") && $fieldDef->{type} ne 'date') {    # standard default date formfield type can't parse&format dates
          $time = $fieldDef->getDisplayValue($fieldValue, $web, $topic);
        } else {
          my $format;
          if ($fieldName =~ /^(Changed|Modified|Created|date|createdate)$/) { # SMELL: hardcode datetime vs date format
            $format = $Foswiki::cfg{DateManipPlugin}{DefaultDateTimeFormat} || $Foswiki::cfg{DefaultDateFormat} . ' - $hour:$min';
          }
          $time = Foswiki::Time::formatTime($epoch, $format);
        }

        $html = "<span style='white-space:nowrap'>$time</span>";
      }
      $epoch ||= 0;
      $cell = {
        "display" => $html,
        "epoch" => $epoch,
        "raw" => $time
      };
    } elsif (!$isEscaped && $desc->{data} eq 'topic') {
      $cell = {
        "display" => "<a href='" . Foswiki::Func::getViewUrl($web, $topic) . "' style='white-space:nowrap'>$topic</a>",
        "raw" => $topic,
      };
    } elsif (!$isEscaped && (
        $desc->{data} =~ /^(author|createauthor)$/ 
        || ($fieldDef && $fieldDef->{type} eq 'user') 
        || $desc->{type} eq 'user'
      )) {
      my @html = ();
      foreach my $item (sort split(/\s*,\s*/, $fieldValue)) {
        #next if $item eq 'AdminUser'; # SMELL: hard coded exclude value
        if (Foswiki::Func::topicExists($Foswiki::cfg{UsersWebName}, $item)) {
          my $topicTitle = Foswiki::Func::getTopicTitle($Foswiki::cfg{UsersWebName}, $item);
          push @html, "<a href='" . Foswiki::Func::getViewUrl($Foswiki::cfg{UsersWebName}, $item) . "' style='white-space:nowrap'>$topicTitle</a>";
        } else {
          push @html, $item;
        }
      }
      $cell = {
        "display" => join(", ", @html),
        "raw" => $fieldValue || "",
      };
    } elsif (!$isEscaped && $desc->{type} eq 'web') {
      my ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($fieldValue, $Foswiki::cfg{HomeTopicName});
      my $html = "<a href='" . Foswiki::Func::getViewUrl($thisWeb, $thisTopic) . "'>".Foswiki::Func::getTopicTitle($thisWeb, $thisTopic)."</a>";
      $cell = {
        display => $html,
        raw => $fieldValue || ''
      };
    } elsif (!$isEscaped && (
        ($fieldDef && $fieldDef->{type} =~ /^(cat|topic)/) 
        || $desc->{type} eq 'topic'
      )) {

      my @html = ();
      foreach my $item (split(/\s*,\s*/, $fieldValue)) {
        my ($thisWeb, $thisTopic) = Foswiki::Func::normalizeWebTopicName($web, $item);
        my $html = $fieldDef->getDisplayValue($thisTopic, $thisWeb, $thisTopic);
        $html = Foswiki::Func::expandCommonVariables($html, $thisTopic, $thisWeb) if $html =~ /%/;
        $html = '<noautolink> ' . $html . ' </noautolink>';    # SMELL: if $params{noautolink}
        $html = Foswiki::Func::renderText($html, $thisWeb, $thisTopic);
        push @html, $html;
      }

      $cell = {
        "display" => join(", ", @html),
        "raw" => $fieldValue || "",
      };
    } elsif (!$isEscaped && (
        $fieldName =~ /(Image|Photo|Logo|thumbnail)/
        || $desc->{type} eq 'image'
      )) { 
      my $url = $fieldValue;

      unless ($url =~ /^(http:)|\//) {
        $url = Foswiki::Func::getPubUrlPath($web, $topic, $fieldValue);
      }
      $url =~ s/%PUBURLPATH%/$Foswiki::cfg{PubUrlPath}/g;

      my $html =
        $fieldValue
        ? "<img src='$url' style='max-width:100%;width:5em;height:5em;object-fit:cover' />"
        : "";

      $cell = {
        "display" => $html,
        "raw" => $fieldValue || "",
      };
    } elsif (!$isEscaped && ( $desc->{data} =~ /^icon$/i || $desc->{type} eq 'icon')) {
      my $html = Foswiki::Plugins::JQueryPlugin::handleJQueryIcon($this->{session}, $fieldValue, $topic, $web);

      $cell = {
        "display" => $html,
        "raw" => $fieldValue || "",
      };

    } elsif (!$isEscaped && ($desc->{data} =~ /^email$/i || $desc->{type} eq 'email')) {
      my $html = $fieldValue ? "<a href='mailto:$fieldValue'>$fieldValue</a>" : "";
      $cell = {
        "display" => $html,
        "raw" => $fieldValue || "",
      };
    } else {

      my $html = $fieldValue;

      # try to render it for display
      if ($fieldDef) {

        # patch in a random field name so that they are different on each row
        # required for older JQueryPlugins
        my $oldFieldName = $fieldDef->{name};
        $fieldDef->{name} .= int(rand(10000)) + 1;

        if ($fieldDef->can("getDisplayValue")) {
          $html = $fieldDef->getDisplayValue($fieldValue, $web, $topic);
        } else {
          $html = $fieldDef->renderForDisplay('$value(display)', $fieldValue, undef, $web, $topic);
        }
        
        $html = Foswiki::Func::decodeFormatTokens($html);
        $html = Foswiki::Func::expandCommonVariables($html, $topic, $web) if $html =~ /%/;
        $html = '<noautolink> ' . $html . ' </noautolink>';    # SMELL: if $params{noautolink}
        $html = Foswiki::Func::renderText($html, $web, $topic);
        $html =~ s/<\/?noautolink>//g;
        $html =~ s/^\s+//g;
        $html =~ s/\s+$//g;
        $html = $this->translate($html, $web, $topic) if $this->isValueMapped($fieldDef);

        # restore original name in form definition to prevent sideeffects
        $fieldDef->{name} = $oldFieldName;
      }

      if ($isLinked) {
        $html = "<a href='" . Foswiki::Func::getViewUrl($web, $topic) . "'>$html</a>";
      }

      $cell = {
        "display" => $html,
        "raw" => $fieldValue,
      };
    }

    if ($cell) {
      $row{$fieldName} = $cell;
      $count++;
    }
  }
  return unless $count;

  return \%row;
}

=begin TML

---++ ObjectMethod isValueMapped( $fieldDef ) -> $boolean

should be in FieldDefinition

=cut

sub isValueMapped {
  my ($this, $fieldDef) = @_;

  return $fieldDef ? $fieldDef->can("isValueMapped") ? $fieldDef->isValueMapped() : $fieldDef->{type} =~ /\+values/ : 0;
}


1;
