package Foswiki::Plugins::JQDataTablesPlugin::DataTables;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;
    return bless(
        $class->SUPER::new(
            $session,
            name       => 'DataTables',
            version    => '1.9.4',
            author     => 'Allan Jardine',
            homepage   => 'http://datatables.net/',
            puburl     => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css        => ['jquery.datatables.css'],
            javascript => [
                'jquery.datatables.js', 'date-foswiki.js',
                'currency.js',          'metrics.js',
                'jquery.datatables.init.js'
            ],
            dependencies => [ 'JQUERYPLUGIN::THEME', 'metadata', 'livequery' ],
            summary      => <<SUMMARY),              $class );
!DataTables is a plug-in for the jQuery Javascript library. It is a highly flexible tool, based upon the foundations of progressive enhancement, which will add advanced interaction controls to any HTML table.
SUMMARY
}

1;
