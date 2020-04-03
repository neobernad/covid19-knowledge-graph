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
        SET citeSpan.ref_id = coalesce(article.id + json_cite_span.ref_id, null)
        MERGE (abstract)-[:constains_citespan]->(citeSpan)
    )
    FOREACH (json_ref_span in  paragraph.ref_spans |
        MERGE (refSpan:RefSpan {
            start: json_ref_span.start,
            end: json_ref_span.end,
            text: json_ref_span.text
        }) ON CREATE
        SET refSpan.ref_id = coalesce(article.id + json_ref_span.ref_id, null)
        MERGE (abstract)-[:constains_refspan]->(refSpan)
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
        SET citeSpan.ref_id = coalesce(article.id + json_cite_span.ref_id, null)
        MERGE (bodytext)-[:constains_citespan]->(citeSpan)
    )
    FOREACH (json_ref_span in  paragraph.ref_spans |
        MERGE (refSpan:RefSpan {
            start: json_ref_span.start,
            end: json_ref_span.end,
            text: json_ref_span.text
        }) ON CREATE
        SET refSpan.ref_id = coalesce(article.id + json_ref_span.ref_id, null)
        MERGE (bodytext)-[:constains_refspan]->(refSpan)
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
// Foreach BibEntry
FOREACH (bibEntryKey in keys(item.bib_entries) |
  FOREACH (jsonEntry in item.bib_entries[bibEntryKey] |
      MERGE (bibEntry : BibEntry {
        id : article.id + bibEntryKey,
        title : jsonEntry.title,
        venue : jsonEntry.venue,
        volume : jsonEntry.volume,
        issn : jsonEntry.issn,
        pages : jsonEntry.pages
      }) ON CREATE
      SET bibEntry.year = coalesce(jsonEntry.year, null)
      MERGE (article)-[:has_bibentry]->(bibEntry)
      FOREACH ( json_author in jsonEntry.authors |
        MERGE (author:Author {
          first: json_author.first,
          middle: json_author.middle, 
          last: json_author.last, 
          suffix: json_author.suffix})
          //TODO: SET author.affiliation = json_author.affiliation
        MERGE (bibEntry)-[:has_author]->(author)
      )
      FOREACH (other_ids_key in keys(jsonEntry.other_ids) |
        FOREACH( other_ids_json in jsonEntry.other_ids[other_ids_key] |
          FOREACH (other_ids_entry in other_ids_json |
            MERGE (reference : DOI {
              id : other_ids_entry
            })
            MERGE (reference)-[:has_reference]->(bibEntry)
          )
        )
      )
  )
)
// Foreach RefEntry
FOREACH (refEntryKey in keys(item.ref_entries) |
  FOREACH (jsonEntry in item.ref_entries[refEntryKey] |
      MERGE (refEntry : RefEntry {
        id : article.id + refEntryKey,
        text : jsonEntry.text,
        type : jsonEntry.type
      }) ON CREATE
      SET refEntry.latex = coalesce(jsonEntry.latex, null)
      MERGE (article)-[:has_refentry]->(refEntry)
  )
)
// Process back_matter
FOREACH (paragraph in item.back_matter | 
    MERGE (back_matter:Paragraph {
          text: paragraph.text,
          section: paragraph.section
    })
    FOREACH (json_cite_span in  paragraph.cite_spans |
        MERGE (citeSpan:CiteSpan {
            start: json_cite_span.start,
            end: json_cite_span.end,
            text: json_cite_span.text
        }) ON CREATE
        SET citeSpan.ref_id = coalesce(article.id + json_cite_span.ref_id, null)
        MERGE (back_matter)-[:constains_citespan]->(citeSpan)
    )
    FOREACH (json_ref_span in  paragraph.ref_spans |
        MERGE (refSpan:RefSpan {
            start: json_ref_span.start,
            end: json_ref_span.end,
            text: json_ref_span.text
        }) ON CREATE
        SET refSpan.ref_id = coalesce(article.id + json_ref_span.ref_id, null)
        MERGE (back_matter)-[:constains_refspan]->(refSpan)
    )
    MERGE (article)-[:has_back_matter]->(back_matter)
)
WITH article
// Link CiteSpan to respective BibEntry
MATCH(citeSpan:CiteSpan)
WHERE citeSpan.ref_id IS NOT NULL
WITH article, citeSpan
MATCH (bibEntry:BibEntry {id: citeSpan.ref_id})
MERGE (citeSpan)-[:has_bibentry]->(bibEntry)
WITH article
// Link RefSpan to respective RefEntry
MATCH(refSpan:RefSpan)
WHERE refSpan.ref_id IS NOT NULL
WITH refSpan
MATCH (refEntry:RefEntry {id: refSpan.ref_id})
MERGE (refSpan)-[:has_refentry]->(refEntry)
