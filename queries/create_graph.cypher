// MATCH (n)
// DETACH DELETE n
CALL apoc.load.json("2_article.json") YIELD value
UNWIND value as item
// Foreach article
MERGE(article:Article {id:item.paper_id}) ON CREATE
    SET article.title = item.metadata.title
    SET article.license = item.metadata.license
// Foreach author
FOREACH (json_author in item.metadata.authors |
    MERGE (author:Author {first: json_author.first,
        middle: json_author.middle, last: json_author.last, suffix: json_author.suffix}) ON CREATE
        //TODO: SET author.affiliation = json_author.affiliation
        SET author.email = json_author.email
    MERGE (article)-[:has_author]->(author)
    )
// Get metadata annotations
WITH item, article
UNWIND keys(item.metadata.termite_hits) as ontology
FOREACH (annotation in  item.metadata.termite_hits[ontology] |
    FOREACH (i IN RANGE(0, annotation.hit_count-1) |             
      MERGE (term:Term {
          id: annotation.id,
          name:annotation.name
          })
      MERGE (article)-[:has_metadata_annotations {
        hit_sentences: annotation.hit_sentences[i],
        hit_sentence_start: annotation.hit_sentence_locations[i][0],
        hit_sentence_end: annotation.hit_sentence_locations[i][1]
      }]->(term)
      MERGE (ontologyNode:Ontology {
          name: ontology
      })
      MERGE (ontologyNode)<-[:from_ontology]-(term)
    )
)
// Foreach paragraph in abstract
FOREACH (paragraph in item.abstract | 
    MERGE (abstract:Paragraph {
          text: paragraph.text,
          section: paragraph.section
    })
    FOREACH (json_cite_span in  paragraph.cite_spans |
        MERGE (citeSpan:CiteSpan {
            start: json_cite_span.start,
            end: json_cite_span.end,
            text: json_cite_span.text
        }) ON CREATE
        SET citeSpan.ref_id = coalesce(json_cite_span.ref_id, null)
        MERGE (abstract)-[:constains_citespan]->(citeSpan)
    )
    FOREACH (ontology in  keys(paragraph.termite_hits)  |
      FOREACH (annotation in  paragraph.termite_hits[ontology]  |
        FOREACH (i IN RANGE(0, annotation.hit_count-1) |             
          MERGE (term:Term {
              id: annotation.id,
              name:annotation.name
              })
          MERGE (abstract)-[:has_annotations {
            hit_sentences: annotation.hit_sentences[i],
            hit_sentence_start: annotation.hit_sentence_locations[i][0],
            hit_sentence_end: annotation.hit_sentence_locations[i][1]
          }]->(term)
          MERGE (ontologyNode:Ontology {
            name: ontology
          })
          MERGE (ontologyNode)<-[:from_ontology]-(term)
        )
      )
    )         
    MERGE (article)-[:has_abstract]->(abstract)
)
// Foreach paragraph in body_text
FOREACH (paragraph in item.body_text | 
    MERGE (bodytext:Paragraph {
          text: paragraph.text,
          section: paragraph.section
    })
    FOREACH (json_cite_span in  paragraph.cite_spans |
        MERGE (citeSpan:CiteSpan {
            start: json_cite_span.start,
            end: json_cite_span.end,
            text: json_cite_span.text
        }) ON CREATE
        SET citeSpan.ref_id = coalesce(json_cite_span.ref_id, null)
        MERGE (bodytext)-[:constains_citespan]->(citeSpan)
    )
    FOREACH (ontology in  keys(paragraph.termite_hits)  |
      FOREACH (annotation in  paragraph.termite_hits[ontology]  |
        FOREACH (i IN RANGE(0, annotation.hit_count-1) |             
          MERGE (term:Term {
              id: annotation.id,
              name:annotation.name
              })
          MERGE (bodytext)-[:has_annotations {
            hit_sentences: annotation.hit_sentences[i],
            hit_sentence_start: annotation.hit_sentence_locations[i][0],
            hit_sentence_end: annotation.hit_sentence_locations[i][1]
          }]->(term)
          MERGE (ontologyNode:Ontology {
            name: ontology
          })
          MERGE (ontologyNode)<-[:from_ontology]-(term)
        )
      )
    )         
    MERGE (article)-[:has_bodytext]->(bodytext)
)