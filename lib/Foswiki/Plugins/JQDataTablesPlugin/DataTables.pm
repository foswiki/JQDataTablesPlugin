package Foswiki::Plugins::JQDataTablesPlugin::DataTables;
use strict;
use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
    my $class   = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;
    my $this    = bless(
        $class->SUPER::new(
            $session,
            name       => 'DataTables',
            version    => '1.9.4',
            author     => 'Allan Jardine',
            homepage   => 'http://datatables.net/',
            puburl     => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css        => ['media/css/jquery.dataTables_themeroller.css'],
            javascript => ['media/js/jquery.dataTables.js'],
            summary    => <<SUMMARY), $class );
!DataTables is a plug-in for the jQuery Javascript library. It is a highly flexible tool, based upon the foundations of progressive enhancement, which will add advanced interaction controls to any HTML table.
SUMMARY
    return $this;
}

sub renderCSS {
    my ( $this, $text ) = @_;

    $text =~ s/\.min// if $this->{debug};
    $text .= '?version=' . $this->{version};
    $text =
"<link rel='stylesheet' href='$this->{puburl}/$text' type='text/css' media='all' />\n";

    return $text;
}

sub renderJS {
    my ( $this, $text ) = @_;

    #    $text =~ s/\.min//
    #      if ( $this->{debug} );

    $text .= '?version=' . $this->{version} if ( $this->{version} =~ '$Rev$' );
    $text =
        "<script type='text/javascript' src='$this->{puburl}/$text'></script>\n"
      . "<script type='text/javascript'>
			\$(document).ready(function() {
				\$('table').dataTable();
			} );
</script>\n";
    return $text;
}

1;
