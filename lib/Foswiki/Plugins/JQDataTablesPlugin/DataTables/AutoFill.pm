package Foswiki::Plugins::JQDataTablesPlugin::DataTables::AutoFill;

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
            name         => 'DataTablesAutoFill',
            version      => '2.1.1',
            author       => 'SpryMedia Ltd',
            homepage     => 'http://datatables.net/',
            puburl       => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css          => ['AutoFill/css/autoFill.dataTables.min.css'],
            javascript   => ['AutoFill/js/dataTables.autoFill.js'],
            dependencies => ['datatables'],
        ),
        $class
    );
}

1;
