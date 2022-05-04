# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# JQDataTablesPlugin is Copyright (C) 2013-2022 Michael Daum http://michaeldaumconsulting.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQDataTablesPlugin::DataTables::FixedColumns;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
use Foswiki::Plugins ();
our @ISA = 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  return bless(
    $class->SUPER::new(
      $session,
      name => 'DataTablesFixedColumns',
      version => '3.2.5',
      author => 'SpryMedia Ltd',
      homepage => 'http://datatables.net/',
      puburl => '%PUBURLPATH%/%SYSTEMWEB%/JQDataTablesPlugin',
      css => ['FixedColumns/css/fixedColumns.dataTables.min.css'],
      javascript => ['FixedColumns/js/dataTables.fixedColumns.min.js'],
      dependencies => ['datatables'],
    ),
    $class
  );
}

1;
