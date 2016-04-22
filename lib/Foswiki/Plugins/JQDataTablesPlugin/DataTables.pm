package Foswiki::Plugins::JQDataTablesPlugin::DataTables;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Func                          ();
use Foswiki::Plugins                       ();
use Foswiki::OopsException                 ();
use Error qw(:try);
use JSON ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    return bless(
        $class->SUPER::new(
            $session,
            name       => 'DataTables',
            version    => '1.10.11',
            author     => 'SpryMedia Ltd',
            homepage   => 'http://datatables.net/',
            puburl     => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
            css        => ['jquery.datatables.css'],
            javascript => [
                'DataTables/js/jquery.dataTables.min.js',
                'jquery.datatables.addons.js'
            ],
            i18n => $Foswiki::cfg{SystemWebName} . "/JQDataTablesPlugin/i18n",
            dependencies => [ 'metadata', 'livequery', 'i18n' ],
            summary => <<SUMMARY), $class );
!DataTables is a plug-in for the jQuery Javascript library. It is a highly
flexible tool, based upon the foundations of progressive enhancement, which
will add advanced interaction controls to any HTML table.
SUMMARY
}

sub _push {
    my ( $this, $array, $key, $val ) = @_;

    if ( ref($val) ) {
        $val = $this->_json->encode($val);
    }
    else {
        $val = Foswiki::entityEncode($val);
    }
    push @$array, "data-$key='$val'";
}

sub _json {
    my $this = shift;

    unless ( defined $this->{_json} ) {
        $this->{_json} = JSON->new;
    }

    return $this->{_json};
}

sub handleDataTable {
    my ( $this, $params, $topic, $web ) = @_;

    my $html5Data = [];

    my $theClass = $params->{class} || '';
    my $theWidth = $params->{width};
    $theWidth = defined($theWidth) ? "width='$theWidth'" : "";

    my $theWeb  = $params->{web}  || $web;
    my $theForm = $params->{form} || '';

    my $thePaging =
      Foswiki::Func::isTrue( $params->{paging} || $params->{pager}, 0 )
      ? 'true'
      : 'false';
    my $theScrolling =
      Foswiki::Func::isTrue( $params->{scrolling} || $params->{scroller}, 0 )
      ? 'true'
      : 'false';

    if ( $theScrolling eq 'true' ) {
        Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesscroller");
        $this->_push( $html5Data, "scroller",     $theScrolling );
        $this->_push( $html5Data, "defer-render", 'true' );
        $this->_push( $html5Data, "paging",       'true' );
    }
    else {
        $this->_push( $html5Data, "paging", $thePaging );
    }

    my $theSearching =
      Foswiki::Func::isTrue( $params->{searching}, 0 ) ? 'true' : 'false';
    my $theSearchMode = $params->{searchmode} || 'global';
    $this->_push( $html5Data, "searching",   $theSearching );
    $this->_push( $html5Data, "search-mode", $theSearchMode );

    my $theReverse =
      Foswiki::Func::isTrue( $params->{reverse}, 0 ) ? 'desc' : 'asc';

    my $theInfo =
      Foswiki::Func::isTrue( $params->{info}, 0 ) ? 'true' : 'false';
    $this->_push( $html5Data, "info", $theInfo );

    my $theOrdering =
      Foswiki::Func::isTrue( $params->{ordering}, 1 ) ? 'true' : 'false';
    $this->_push( $html5Data, "ordering", $theOrdering );

    my $theScrollX =
      Foswiki::Func::isTrue( $params->{scrollx}, 0 ) ? 'true' : 'false';
    $this->_push( $html5Data, "scroll-x", $theScrollX );

    my $theScrollY =
      $params->{scrolly} || ( $theScrolling eq 'true' ? 200 : "" );
    $this->_push( $html5Data, "scroll-y", $theScrollY ) if $theScrollY;

    my $theScrollCollapse =
      Foswiki::Func::isTrue( $params->{scrollcollapse}, 0 ) ? 'true' : 'false';
    $this->_push( $html5Data, "scroll-collapse", $theScrollCollapse );

    my $theSearchDelay = $params->{searchdelay} || "400";
    $this->_push( $html5Data, "search-delay", $theSearchDelay );

    my $theSort = $params->{sort} || '';

    my $theLengthMenu = $params->{lengthmenu} || '';
    if ($theLengthMenu) {
        $this->_push( $html5Data, "length-change", "true" );
        $this->_push( $html5Data, "length-menu",
            [ map { int($_) } split( /\s*,\s*/, $theLengthMenu ) ] );
    }

    my $thePageLength = $params->{rows} || $params->{pagelength};
    $this->_push( $html5Data, "page-length", $thePageLength ) if $thePageLength;

    my @selectedFields = ();
    my $formParam      = '';

    my $theCols = $params->{columns};
    if ($theCols) {
        foreach my $fieldName ( split( /\s*,\s*/, $theCols ) ) {
            push @selectedFields, $fieldName;
        }
    }

    my $theSelecting = Foswiki::Func::isTrue( $params->{selecting}, 0 );
    my $theSelectMode     = $params->{selectmode}     || "multiple";
    my $theSelectProperty = $params->{selectproperty} || "Topic";
    my $selectInput       = "";
    if ($theSelecting) {
        Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesselect");

        my $selectOpts = {
            style    => $theSelectMode,
            property => $theSelectProperty,
        };

        my $theSelection = $params->{selection};
        if ( defined $theSelection && $theSelection ne "" ) {
            $selectOpts->{selection} = [ split( /\s*,\s*/, $theSelection ) ];
        }

        $this->_push( $html5Data, "select", $selectOpts );

        $selectInput =
"<input type='hidden' name='$theSelectProperty' class='selectInput' />";
    }

    my $theResponsive = Foswiki::Func::isTrue( $params->{responsive}, 0 );
    if ($theResponsive) {
        Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesresponsive");

        $this->_push( $html5Data, "responsive", "true" );
    }

    my $theFixedHeader = Foswiki::Func::isTrue( $params->{fixedheader}, 0 );
    if ($theFixedHeader) {
        Foswiki::Plugins::JQueryPlugin::createPlugin("datatablesfixedheader");

        $this->_push( $html5Data, "fixed-header", "true" );
    }

    if ($theForm) {
        my ( $formWeb, $formTopic ) =
          Foswiki::Func::normalizeWebTopicName( $theWeb, $theForm );
        $formWeb =~ s/\//./g;

        my $form;
        my $error;
        my $session = $this->{session} || $Foswiki::Plugins::SESSION;
        try {
            $form = new Foswiki::Form( $session, $formWeb, $formTopic );
        }
        catch Foswiki::OopsException with {
            $error =
"<div class='foswikiAlert'>ERROR: form $formWeb.$formTopic not found.</div>";
        };
        return $error if $error;
        if ( $form && !$theCols ) {
            @selectedFields = map { $_->{name} } @{ $form->getFields() };

            #unshift @selectedFields, "Topic";
        }

        $formParam = $formTopic;
    }

    my @thead = ();

    #my @tfoot = ();
    my @multiFilter = ();
    my @columns     = ();

    push @thead, "<tr>";
    my $index = 0;

    unless ( grep { /^($theSelectProperty)$/i } @selectedFields ) {
        push @columns,
          {
            data    => $theSelectProperty,
            name    => $theSelectProperty,
            visible => JSON::false,
          };
        push @thead,       "<th>$theSelectProperty</th>";
        push @multiFilter, "<th></th>";
        $index++;
    }

    if ($theSelecting) {
        push @columns,
          {
            data       => "null",
            searchable => JSON::false,
            orderable  => JSON::false,
          };
        push @thead, "<th><input type='checkbox' class='selectAll' /></th>";
        push @multiFilter, "<th></th>";
        $index++;
    }

    my $order = [ [ 0, $theReverse ] ];    # default
    foreach my $fieldName (@selectedFields) {
        push @thead, "<th>$fieldName</th>";
        my $col = {
            "data" => $fieldName,
            "name" => $fieldName
        };

        if ( $fieldName eq 'index' ) {
            $col->{render} = {
                "_"       => "raw",
                "display" => "display",
            };
            $col->{title}      = "";
            $col->{searchable} = JSON::false;
            $col->{orderable}  = JSON::false;
        }
        elsif ( $fieldName =~
            /^(Date|Changed|Modified|Created|info\.date|createdate)$/ )
        {
            $col->{render} = {
                "_"       => "raw",
                "display" => "display",
                "sort"    => "epoch",
            };
        }
        else {
            $col->{render} = {
                "_"       => "raw",
                "display" => "display",
            };
        }

        if ( !defined( $col->{searchable} )
            || $col->{searchable} eq JSON::true )
        {
            push @multiFilter,
"<th><input type='text' class='colSearch foswikiInputField' data-column='$fieldName' /></th>";
        }
        else {
            push @multiFilter, "<th></th>";
        }

        my $title = $params->{ $fieldName . '_title' };
        if ($title) {
            $col->{title} = $title;
        }

        my $width = $params->{ $fieldName . '_width' };
        if ($width) {
            $col->{width} = $width;
        }

        push @columns, $col;
        $order = [ [ $index, "$theReverse" ] ] if $theSort eq $fieldName;
        $index++;
    }
    push @thead, "</tr>";

    if ( $theSearchMode eq 'multi' ) {
        unshift @thead, "<tr class='colSearchRow'>", @multiFilter, "</tr>";
    }

    $this->_push( $html5Data, "order", $order );

    my $thead = join( "\n", @thead );
    $this->_push( $html5Data, "columns", \@columns );

    #my $tfoot = join("\n", @tfoot);

    my $time = time();
    my $url =
      Foswiki::Func::getScriptUrl( "JQDataTablesPlugin", "connector", "rest" );
    $this->_push( $html5Data, "server-side", "true" );
    my $connector =
         $params->{connector}
      || $Foswiki::cfg{JQDataTablesPlugin}{DefaultConnector}
      || 'search';

    my $ajax = {
        url  => $url,
        type => "post",
        data => {
            t         => $time,
            form      => $formParam,
            topic     => "$theWeb.WebHome",
            web       => $theWeb,
            connector => $connector,
        },
    };

    my $theQuery = $params->{_DEFAULT} || $params->{query} || '';
    if ($theQuery) {
        $ajax->{data}{query} = Foswiki::entityEncode($theQuery);
    }

    $this->_push( $html5Data, "ajax", $ajax );

    $html5Data = join( " ", @$html5Data );
    my $result = <<"HERE";
<literal>
<div class='jqDataTablesContainer' $html5Data' >
<table class='foswikiTable $theClass' $theWidth>
  <thead>$thead</thead>
  <tbody>
  </tbody>
</table>$selectInput
</div>
</literal>
HERE

    return $result;
}

1;
