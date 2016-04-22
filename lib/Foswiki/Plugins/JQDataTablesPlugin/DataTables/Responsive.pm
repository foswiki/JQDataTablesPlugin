package Foswiki::Plugins::JQDataTablesPlugin::DataTables::Responsive;

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
            name         => 'DataTablesResponsive',
            version      => '2.0.2',
            author       => 'SpryMedia Ltd',
            homepage     => 'http://datatables.net/',
            puburl       => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css          => ['Responsive/css/responsive.dataTables.min.css'],
            javascript   => ['Responsive/js/dataTables.responsive.min.js'],
            dependencies => ['datatables'],
        ),
        $class
    );
}

1;

