# See end of file for license and copyright information
package Foswiki::Plugins::JQDataTablesPlugin;

use strict;
use warnings;

use Assert;
use Error qw(:try);

use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Func ();
use Foswiki::AccessControlException ();

our $VERSION = '3.11';
our $RELEASE = '25 Sep 2017';
our $SHORTDESCRIPTION = 'JQuery based progressive enhancement of tables';

sub initPlugin {

  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesAutoButtons', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Buttons');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesAutoFill', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::AutoFill');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesColReorder', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::ColReorder');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesFixedColumns', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::FixedColumns');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTables', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesResponsive', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Responsive');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesSelect', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Select');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesFixedHeader', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::FixedHeader');
  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesScroller', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::Scroller');

  #  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesJSZip', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::JSZip');
  #  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesKeyTable', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::KeyTable');
  #  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesPDFMaker', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::PDFMaker');
  #  Foswiki::Plugins::JQueryPlugin::registerPlugin('DataTablesRowReorder', 'Foswiki::Plugins::JQDataTablesPlugin::DataTables::RowReorder');

  Foswiki::Func::registerTagHandler('DATATABLE', \&handleDataTable);
  Foswiki::Func::registerRESTHandler(
    'connector', \&restConnector,
    authenticate => 0,
    validate => 0,
    http_allow => 'GET,POST',
  );

  return 1;
}

sub handleDataTable {
  my $session = shift;

  my $plugin = Foswiki::Plugins::JQueryPlugin::createPlugin('datatables');

  return $plugin->handleDataTable(@_) if $plugin;
  return '';
}

sub restConnector {
  my ($session, $subject, $verb, $response) = @_;

  my $request = Foswiki::Func::getCgiQuery();

  my $connectorID =
       $request->param('connector')
    || $Foswiki::cfg{JQDataTablesPlugin}{DefaultConnector}
    || 'search';
  my $connectorClass = $Foswiki::cfg{JQDataTablesPlugin}{Connector}{$connectorID}
    || $Foswiki::cfg{JQDataTablesPlugin}{ExternalConnectors}{$connectorID};

  unless ($connectorClass) {
    printRESTResult($response, 500, "ERROR: unknown connector");
    return '';
  }

  eval "require $connectorClass";
  if ($@) {
    printRESTResult($response, 500, "ERROR: loading connector");
    #print STDERR "ERROR loading connector $connectorClass: $@\n";
    return '';
  }

  my $connector = $connectorClass->new($session);

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
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

JQTablePlugin is copyright (C) 2012 SvenDowideit@fosiki.com, 2013-2017 Michael Daum http://michaeldaumconsulting.com

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

For licensing info read LICENSE file in the root of this distribution.
