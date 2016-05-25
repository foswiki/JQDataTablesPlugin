package Foswiki::Plugins::JQDataTablesPlugin::DataTables::FixedHeader;

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
      name => 'DataTablesFixedHeader',
      version => '3.1.2',
      author => 'SpryMedia Ltd',
      homepage => 'http://datatables.net/',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
      css => ['FixedHeader/css/fixedHeader.dataTables.min.css'],
      javascript => ['FixedHeader/js/dataTables.fixedHeader.min.js'],
      dependencies => ['datatables'],
    ),
    $class
  );
}

1;

