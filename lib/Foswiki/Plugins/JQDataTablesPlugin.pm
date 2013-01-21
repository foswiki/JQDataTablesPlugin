# See end of file for license and copyright information
package Foswiki::Plugins::JQDataTablesPlugin;

use strict;
use Assert;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version

our $VERSION           = '1.0.0';
our $RELEASE           = '1.0.0';
our $SHORTDESCRIPTION  = 'Jquery based progressive enhancement of tables';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    return 1;
}

1;
__END__
Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

JQTablePlugin is copyright (C)SvenDowideit@fosiki.com

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

For licensing info read LICENSE file in the root of this distribution.
