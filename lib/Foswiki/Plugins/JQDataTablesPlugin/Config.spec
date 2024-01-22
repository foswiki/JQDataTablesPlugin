# ---+ Extensions
# ---++ JQDataTablesPlugin
# ---+++ DataTable Connectors
# **STRING 50**
# Default connector used when no other <code>connector</code> parameter is specified to the <code>%DATATABLE</code> macro.
$Foswiki::cfg{JQDataTablesPlugin}{DefaultConnector} = 'search';

# **STRING 50**
# Implementation handling the default <code>search</code> connector based on Foswiki's standard <code>%SEARCH</code>
# implementation. Note that for adequat performance you are recommended to use a better search algorithm than the default
# grep-based, or use the DBCachePlugin or SolrPlugin backends. See Foswiki::Store::SearchAlgorithms.
$Foswiki::cfg{JQDataTablesPlugin}{Connector}{search} =
  'Foswiki::Plugins::JQDataTablesPlugin::SearchConnector';

# **STRING 50**
# Implementation handling the <code>dbcache</code> connector. This will require DBCachePlugin to be installed.
$Foswiki::cfg{JQDataTablesPlugin}{Connector}{dbcache} =
  'Foswiki::Plugins::JQDataTablesPlugin::DBCacheConnector';

# **STRING 50**
# Implementation handling the <code>solr</code> connector. This will require SolrPlugin to be installed.
$Foswiki::cfg{JQDataTablesPlugin}{Connector}{solr} =
  'Foswiki::Plugins::JQDataTablesPlugin::SolrConnector';

# **PERL**
# Perl hashmap to integrate with custom grid connectors.
$Foswiki::cfg{JQDataTablesPlugin}{ExternalConnectors} = { my_grid_connector =>
      'Foswiki::Plugins::MyGridConnectorPlugin::MyConnector' };

1;

