package Foswiki::Plugins::JQDataTablesPlugin::DataTables::FixedColumns;

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
            name         => 'DataTablesFixedColumns',
            version      => '3.2.2',
            author       => 'SpryMedia Ltd',
            homepage     => 'http://datatables.net/',
            puburl       => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css          => ['FixedColumns/css/fixedColumns.dataTables.css'],
            javascript   => ['FixedColumns/js/dataTables.fixedColumns.js'],
            dependencies => ['datatables'],
        ),
        $class
    );
}

1;
