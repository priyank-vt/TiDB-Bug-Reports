-- Statements executed through the unauthenticated GetTiFlashSystemTable gRPC method.
-- Each was sent verbatim as TiFlashSystemTableRequest.sql; full JSON responses captured.

-- probe1: storage metadata of user tables
SELECT * FROM system.dt_tables LIMIT 3;

-- probe2: complete database inventory with internal IDs and storage paths
SELECT * FROM system.databases;

-- probe3: arbitrary SELECT outside the intended dt_* tables accepted
SELECT number FROM system.numbers LIMIT 3;

-- probe5: further non-dt_* table accepted
SELECT * FROM system.one;

-- probe7: column-level schema of all replicated user tables
SELECT * FROM system.columns LIMIT 5;

-- probe8: in-flight query text with client IP/port of other users
SELECT * FROM system.processes LIMIT 3;

-- probe9: full engine configuration dump
SELECT * FROM system.settings;

-- probe12: live engine internals
SELECT * FROM system.metrics LIMIT 4;

-- probe13: build fingerprint
SELECT * FROM system.build_options;

-- probe16: physical segment layout with TiDB db/table names
SELECT * FROM system.dt_segments;

-- negative control 1: user-table rows by TiDB name -> REJECTED
SELECT * FROM secaudit.t1;

-- negative control 2: TiDB-specific function -> REJECTED
SELECT currentUser();

-- resource-hold variant: holds one gRPC worker until client deadline
SELECT number FROM system.numbers;
