//>> Create termIndex for typeahead in Terms.

CALL db.index.fulltext.createNodeIndex('termIndex', ['Term'], ['name'])
CALL db.indexes
// Test:
CALL db.index.fulltext.queryNodes('termIndex', 'input~')
YIELD node, score
RETURN node ORDER BY score DESC LIMIT 10


//>> Create index for article id, to retrieve the articles.

CREATE INDEX articleId FOR (n:Article) ON (n.id)

//>> Find articles depending on Term ID
Match (t:Term {id:"https://id.nlm.nih.gov/mesh/D010944"})<-[*..1]-(a:Article {id: "3b8d7417f616e8ba9912423e9b764870d8e2e047"})
WITH a
MATCH (a)-[:has_abstract]->(abstract:Paragraph)
RETURN a, abstract SKIP 'PAGE' LIMIT 'PAGE_SIZE'
// Change PAGE_SIZE and PAGE to proper values.

// Article view

//> (Cloud of tags with pagination)
Match (t:Term)<-[r:has_annotations]-(p:Paragraph)<-[*..1]-(a:Article {id:"5650690daf962117b9831c42178ffd6a6a969300"})
RETURN t  SKIP 'PAGE' LIMIT 'PAGE_SIZE'
// Change PAGE_SIZE and PAGE to proper values.

//>> Find spans from a given term ID (cloud of tags)
Match (t:Term {id:"https://id.nlm.nih.gov/mesh/D006801"})<-[r:has_annotations]-(p:Paragraph)<-[*..1]-(a:Article {id:"5650690daf962117b9831c42178ffd6a6a969300"})
RETURN t, p, COLLECT(r) as spans ORDER BY p.position ASC SKIP 'PAGE' LIMIT 'PAGE_SIZE'

// Cloud
// Title
// Abstract
// Paragraph
// Back matter
// Citations


//>> 