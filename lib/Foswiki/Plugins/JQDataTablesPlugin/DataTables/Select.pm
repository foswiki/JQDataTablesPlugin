package Foswiki::Plugins::JQDataTablesPlugin::DataTables::Select;

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
            name     => 'DataTablesSelect',
            version  => '1.2.0',
            author   => 'SpryMedia Ltd',
            homepage => 'http://datatables.net/',
            puburl   => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',

            #css          => ['Select/css/select.dataTables.min.css'],
            javascript   => ['Select/js/dataTables.select.min.js'],
            dependencies => ['datatables'],
        ),
        $class
    );
}

1;

