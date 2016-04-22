package Foswiki::Plugins::JQDataTablesPlugin::DataTables::Buttons;

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
            name       => 'DataTablesButtons',
            version    => '1.1.2',
            author     => 'SpryMedia Ltd',
            homepage   => 'http://datatables.net/',
            puburl     => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css        => ['Buttons/css/buttons.dataTables.min.css'],
            javascript => [
                'Buttons/js/dataTables.buttons.min.js',
                'Buttons/js/buttons.colVis.min.js',
                'Buttons/js/buttons.html5.min.js',
                'Buttons/js/buttons.print.min.js',
            ],
            dependencies => ['datatables'],
        ),
        $class
    );
}

1;

