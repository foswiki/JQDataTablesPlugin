FOSWIKI_ROOT?=~/foswiki/core
TARGET=jquery.datatables.addons.js jquery.datatables.css jquery.datatables.js

ADDONS_SOURCE=\
  date-foswiki.uncompressed.js \
  datetime-moment.uncompressed.js \
  currency.uncompressed.js \
  metrics.uncompressed.js \
  jquery.datatables.init.uncompressed.js


-include $(FOSWIKI_ROOT)/pub/System/JQueryPlugin/Makefile.include

clean:
	rm -f $(TARGET) *.gz *.map

jquery.datatables.uncompressed.js: DataTables/js/jquery.dataTables.js
	@echo generating $@
	@$(CAT) $^ > $@

jquery.datatables.addons.uncompressed.js: $(ADDONS_SOURCE)
	@echo generating $@
	@$(CAT) $^ > $@


