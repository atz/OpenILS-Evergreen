#-----------------------------------------------------------
# Makefile.am for Open-ILS/src/c-apps
# Author: Kevin Beswick (kevinbeswick00@gmail.com)
# Process this file with automake to generate Makefile.in
#-----------------------------------------------------------

AM_CFLAGS = $(DEF_CFLAGS) -DOSRF_LOG_PARAMS -I@top_srcdir@/include/
AM_LDFLAGS = $(DEF_LDFLAGS) -L$(DBI_LIBS) -lopensrf 

bin_PROGRAMS = oils_dataloader dump_idl test_json_query test_qstore
oils_dataloader_SOURCES = oils_dataloader.c
oils_dataloader_LDFLAGS = $(AM_LDFLAGS) -loils_idl
oils_dataloader_DEPENDENCIES = liboils_idl.la liboils_utils.la

dump_idl_SOURCES = dump_idl.c
dump_idl_LDFLAGS = $(AM_LDFLAGS) -loils_idl
dump_idl_DEPENDENCIES = liboils_idl.la liboils_utils.la

test_json_query_SOURCES = test_json_query.c oils_sql.c
test_json_query_CFLAGS = $(AM_CFLAGS)
test_json_query_LDFLAGS = $(AM_LDFLAGS) -loils_idl -loils_utils
test_json_query_DEPENDENCIES = liboils_idl.la liboils_utils.la

test_qstore_SOURCES = test_qstore.c buildSQL.c oils_buildq.c oils_execsql.c oils_sql.c oils_storedq.c 
test_qstore_CFLAGS = $(AM_CFLAGS)
test_qstore_LDFLAGS = $(AM_LDFLAGS) -loils_idl -loils_utils
test_qstore_DEPENDENCIES = liboils_idl.la liboils_utils.la

lib_LTLIBRARIES = liboils_idl.la liboils_utils.la oils_cstore.la oils_qstore.la oils_rstore.la oils_pcrud.la oils_auth.la

liboils_idl_la_SOURCES = oils_idl-core.c

liboils_utils_la_SOURCES = oils_utils.c oils_event.c

oils_cstore_la_SOURCES = oils_cstore.c oils_sql.c
oils_cstore_la_LDFLAGS = $(AM_LDFLAGS) -loils_idl -ldbi -ldbdpgsql -loils_utils -module
oils_cstore_la_DEPENDENCIES = liboils_idl.la liboils_idl.la

oils_qstore_la_SOURCES = oils_qstore.c oils_sql.c oils_storedq.c oils_buildq.c buildSQL.c oils_execsql.c
oils_qstore_la_LDFLAGS = $(AM_LDFLAGS) -loils_idl -ldbi -ldbdpgsql -loils_utils -module
oils_qstore_la_DEPENDENCIES = liboils_idl.la liboils_idl.la

oils_rstore_la_SOURCES = oils_rstore.c oils_sql.c
oils_rstore_la_LDFLAGS = $(AM_LDFLAGS) -loils_idl -ldbi -ldbdpgsql -loils_utils -module
oils_rstore_la_DEPENDENCIES = liboils_idl.la liboils_idl.la

oils_pcrud_la_SOURCES = oils_pcrud.c oils_sql.c
oils_pcrud_la_LDFLAGS = $(AM_LDFLAGS) -loils_idl -ldbi -ldbdpgsql -loils_utils -module
oils_pcrud_la_DEPENDENCIES = liboils_utils.la liboils_idl.la

oils_auth_la_SOURCES = oils_auth.c
oils_auth_la_LDFLAGS = -module -loils_idl -loils_utils
oils_auth_la_DEPENDENCIES = liboils_utils.la liboils_idl.la


