package Foswiki::Plugins::JQDataTablesPlugin::DataTables::Scroller;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Plugins ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  return bless(
    $class->SUPER::new(
      $session,
      name => 'DataTablesScroller',
      version => '1.4.2',
      author => 'SpryMedia Ltd',
      homepage => 'https://datatables.net/extensions/scroller/',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',

      #css          => ['Scroller/css/scroller.dataTables.min.css'],
      javascript => ['Scroller/js/dataTables.scroller.min.js'],
      dependencies => ['datatables'],
    ),
    $class
  );
}

1;

