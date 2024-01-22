# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2012 SvenDowideit@fosiki.com, 
# Copyright (C) 2013-2024 Michael Daum http://michaeldaumconsulting.com
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the root of this distribution.

package Foswiki::Plugins::JQDataTablesPlugin;

use strict;
use warnings;

use Assert;
use Error qw(:try);

use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Func ();
use Foswiki::AccessControlException ();

our $VERSION = '7.20';
our $RELEASE = '%$RELEASE%';
our $SHORTDESCRIPTION = 'JQuery based progressive enhancement of tables';
our $LICENSECODE = '%$LICENSECODE%';
our %knownConnectors = ();

sub initPlugin {

  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesButtons', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Buttons');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesAutoButtons', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Buttons'); # DEPRECATED
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesPDFMake', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::PDFMake');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesJSZip', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::JSZip');

  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesAutoFill', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::AutoFill');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesColReorder', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::ColReorder');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesFixedColumns', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::FixedColumns');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTables', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesResponsive', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Responsive');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesSelect', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Select');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesFixedHeader', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::FixedHeader');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesScroller', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Scroller');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesRowGroup', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::RowGroup');

  #  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesKeyTable', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::KeyTable');
  #  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesRowReorder', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::RowReorder');

  Foswiki::Func::registerTagHandler('DATATABLESECTION', \&handleDataTableSection);
  Foswiki::Func::registerTagHandler('ENDDATATABLESECTION', \&handleEndDataTableSection);
  Foswiki::Func::registerTagHandler('DATATABLE', \&handleDataTable);

  Foswiki::Func::registerRESTHandler(
    'connector', \&restConnector,
    authenticate => 0,
    validate => 0,
    http_allow => 'GET,POST',
  );

  return 1;
}

sub finishPlugin {
  undef %knownConnectors;
}

sub describeColumn {
  my ($id, $column, $descr) = @_;

  my $conn = Foswiki::Plugins::JQDataTablesPlugin::getConnector($id);
  return 0 unless defined $conn;

  $conn->{columnDescription}{$column} = $descr;

  return 1;
}

sub getConnector {
  my ($id, $session) = @_;

  $session //= $Foswiki::Plugins::SESSION;

  my $connector = $knownConnectors{$id};

  if (defined $connector) {

    $connector = $knownConnectors{$id} = _createConnector($connector, $session)
      unless ref($connector);

  } else {

    my $class = $Foswiki::cfg{JQDataTablesPlugin}{Connector}{$id}
      || $Foswiki::cfg{JQDataTablesPlugin}{ExternalConnectors}{$id};

    return unless $class;

    $connector = $knownConnectors{$id} = _createConnector($class, $session);
  }

  return $connector;
}

sub _createConnector {
  my ($class, $session) = @_;

  my $path = $class.'.pm';
  $path =~ s/::/\//g;

  eval {require $path};
  if ($@) {
    #print STDERR "ERROR loading connector $class: $@\n";
    return;
  }

  return $class->new($session);
}

sub registerConnector {
  my ($id, $class) = @_;

  my $connector = $knownConnectors{$id};
  
  unless (defined $connector) {
    $connector = $knownConnectors{$id} = $class; # delay compilation
  }

  return $connector;
}

sub getDataTables {
  return Foswiki::Plugins::JQueryPlugin::createPlugin('datatables');
}

sub handleDataTable {
  getDataTables->handleDataTable(@_);
}

sub handleDataTableSection {
  getDataTables->handleDataTableSection(@_);
}

sub handleEndDataTableSection {
  getDataTables->handleEndDataTableSection(@_);
}

sub restConnector {
  my ($session, $subject, $verb, $response) = @_;

  my $request = Foswiki::Func::getRequestObject();

  my $connectorID =
       $request->param('connector')
    || $Foswiki::cfg{JQDataTablesPlugin}{DefaultConnector}
    || 'search';

  my $connector = getConnector($connectorID, $session);

  unless ($connector) {
    printRESTResult($response, 500, "ERROR: unknown connector '$connectorID'");
    return;
  }

  my $action = $request->param('oper') || 'search';
  try {
    if ($action eq 'edit') {
      $connector->restHandleSave($request, $response);
    } else {
      $connector->restHandleSearch($request, $response);
    }
  }
  catch Foswiki::AccessControlException with {
    my $error = shift;
    printRESTResult($response, 401, "ERROR: Unauthorized access to $error->{web}.$error->{topic}");
  }
  catch Error::Simple with {
    my $error = shift;
    printRESTResult($response, 500, "ERROR: " . $error);
  };

  return '';
}

sub printRESTResult {
  my ($response, $status, $text) = @_;

  $response->header(
    -status => $status,
    -type => 'text/plain',
  );

  $response->print("$text\n");
}

1;
