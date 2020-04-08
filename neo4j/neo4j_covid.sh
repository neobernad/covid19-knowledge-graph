  docker run \
  	-d \
	--name="neo4j_covid" \
	--publish=7475:7474 \
	--publish=7688:7687 \
	--env=NEO4J_AUTH=none \
	--env=NEO4J_dbms_memory_heap_initial__size=512m --env=NEO4J_dbms_memory_heap_max__size=16384m \
	--env=NEO4J_dbms_security_procedures_unrestricted=apoc.\\\* \
	--env NEO4J_dbms_memory_pagecache_size=16G \
	--env=NEO4J_dbms_allow__upgrade=true \
	--env=NEO4J_dbms_default__listen__address=0.0.0.0 \
	--env=NEO4J_dbms_default__advertised__address=localhost \
	--volume=/data/covid/neo4j/data:/data \
	--volume=/data/covid/neo4j/logs:/logs \
	--volume=/data/covid/neo4j/import:/import \
	--volume=/data/covid/neo4j/conf:/conf \
	--volume=/data/covid/neo4j/plugins:/plugins \
	neo4j:4.0.2

# Note: Make sure that anyone can write in '/path/neo4j-qa/import'
# chmod 777 /path/neo4j-qa/import

# If neo4j:4.0.0, connect using bolt://localhost:7687
# Move the file 'neo4j.conf' into your custom /data/covid/neo4j/conf folder.