package Foswiki::Plugins::JQDataTablesPlugin::DataTables::ColReorder;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Plugins                       ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    return bless(
        $class->SUPER::new(
            $session,
            name         => 'DataTablesColReorder',
            version      => '1.3.2',
            author       => 'SpryMedia Ltd',
            homepage     => 'http://datatables.net/',
            puburl       => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css          => ['ColReorder/css/colReorder.dataTables.min.css'],
            javascript   => ['ColReorder/js/dataTables.colReorder.min.js'],
            dependencies => ['datatables'],
        ),
        $class
    );
}

1;
