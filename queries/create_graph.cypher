CALL apoc.periodic.iterate("
  CALL apoc.load.json('300_article.json') YIELD value
  RETURN value
","
  UNWIND value as item
  MERGE (article:Article {id: item.paper_id})
      SET article.title = item.metadata.title
      SET article.license = item.metadata.license
  FOREACH (json_author in item.metadata.authors |
      MERGE (author:Author {first: json_author.first,
          middle: json_author.middle, last: json_author.last, suffix: json_author.suffix}) ON CREATE
          SET author.email = json_author.email
      MERGE (article)-[:has_author]->(author)
  )
  WITH item, article
  UNWIND keys(item.metadata.termite_hits) as ontology
  FOREACH (annotation in  item.metadata.termite_hits[ontology] |
      FOREACH (i IN RANGE(0, annotation.hit_count-1) |             
        MERGE (term:Term {
            id: annotation.id
        }) ON CREATE
        SET term.name = annotation.name
        CREATE (article)-[:has_metadata_annotations {
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
  FOREACH (i IN RANGE(0, size(item.abstract)-1) |
      MERGE (abstract:Paragraph {
            id: apoc.hashing.fingerprint(item.abstract[i].text),
            position: i
      }) ON CREATE
      SET abstract.text = item.abstract[i].text
      SET abstract.section = item.abstract[i].section
      FOREACH (json_cite_span in  item.abstract[i].cite_spans |
          MERGE (citeSpan:CiteSpan {
              start: json_cite_span.start,
              end: json_cite_span.end,
              text: json_cite_span.text
          }) ON CREATE
          SET citeSpan.ref_id = coalesce(article.id + json_cite_span.ref_id, null)
          MERGE (abstract)-[:contains_citespan]->(citeSpan)
      )
      FOREACH (json_ref_span in  item.abstract[i].ref_spans |
          MERGE (refSpan:RefSpan {
              start: json_ref_span.start,
              end: json_ref_span.end,
              text: json_ref_span.text
          }) ON CREATE
          SET refSpan.ref_id = coalesce(article.id + json_ref_span.ref_id, null)
          MERGE (abstract)-[:contains_refspan]->(refSpan)
      )
      FOREACH (ontology in  keys(item.abstract[i].termite_hits)  |
        FOREACH (annotation in  item.abstract[i].termite_hits[ontology]  |
          FOREACH (i IN RANGE(0, annotation.hit_count-1) |             
            MERGE (term:Term {
                id: annotation.id
            }) ON CREATE
            SET term.name = annotation.name
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
FOREACH (i IN RANGE(0, size(item.body_text)-1) | 
      MERGE (bodytext:Paragraph {
            id: apoc.hashing.fingerprint(item.body_text[i].text),
            position: i
      }) ON CREATE
      SET bodytext.text = item.body_text[i].text
      SET bodytext.section = item.body_text[i].section
      FOREACH (json_cite_span in  item.body_text[i].cite_spans |
          MERGE (citeSpan:CiteSpan {
              start: json_cite_span.start,
              end: json_cite_span.end,
              text: json_cite_span.text
          }) ON CREATE
          SET citeSpan.ref_id = coalesce(article.id + json_cite_span.ref_id, null)
          MERGE (bodytext)-[:contains_citespan]->(citeSpan)
      )
      FOREACH (json_ref_span in  item.body_text[i].ref_spans |
          MERGE (refSpan:RefSpan {
              start: json_ref_span.start,
              end: json_ref_span.end,
              text: json_ref_span.text
          }) ON CREATE
          SET refSpan.ref_id = coalesce(article.id + json_ref_span.ref_id, null)
          MERGE (bodytext)-[:contains_refspan]->(refSpan)
      )
      FOREACH (ontology in  keys(item.body_text[i].termite_hits)  |
        FOREACH (annotation in  item.body_text[i].termite_hits[ontology]  |
          FOREACH (i IN RANGE(0, annotation.hit_count-1) |             
            MERGE (term:Term {
                id: annotation.id
            }) ON CREATE
            SET term.name = annotation.name
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
  FOREACH (bibEntryKey in keys(item.bib_entries) |
    FOREACH (jsonEntry in item.bib_entries[bibEntryKey] |
        MERGE (bibEntry : BibEntry {
          title : jsonEntry.title,
          venue : jsonEntry.venue,
          volume : jsonEntry.volume,
          issn : jsonEntry.issn,
          pages : jsonEntry.pages
        }) ON CREATE
        SET bibEntry.year = coalesce(jsonEntry.year, null)
        SET bibEntry.id = coalesce(article.id + bibEntryKey, null)
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
  FOREACH (i IN RANGE(0, size(item.back_matter)-1) |
      MERGE (back_matter:Paragraph {
            id: apoc.hashing.fingerprint(item.back_matter[i].text),
            position: i
      }) ON CREATE
      SET back_matter.text = item.back_matter[i].text
      SET back_matter.section = item.back_matter[i].section
      FOREACH (json_cite_span in  item.back_matter[i].cite_spans |
          MERGE (citeSpan:CiteSpan {
              start: json_cite_span.start,
              end: json_cite_span.end,
              text: json_cite_span.text
          }) ON CREATE
          SET citeSpan.ref_id = coalesce(article.id + json_cite_span.ref_id, null)
          MERGE (back_matter)-[:contains_citespan]->(citeSpan)
      )
      FOREACH (json_ref_span in  item.back_matter[i].ref_spans |
          MERGE (refSpan:RefSpan {
              start: json_ref_span.start,
              end: json_ref_span.end,
              text: json_ref_span.text
          }) ON CREATE
          SET refSpan.ref_id = coalesce(article.id + json_ref_span.ref_id, null)
          MERGE (back_matter)-[:contains_refspan]->(refSpan)
      )
      MERGE (article)-[:has_back_matter]->(back_matter)
  )
  WITH article
  MATCH(citeSpan:CiteSpan)
  WHERE citeSpan.ref_id IS NOT NULL
  WITH article, citeSpan
  MATCH (bibEntry:BibEntry {id: citeSpan.ref_id})
  MERGE (citeSpan)-[:has_bibentry]->(bibEntry)
  WITH article
  MATCH(refSpan:RefSpan)
  WHERE refSpan.ref_id IS NOT NULL
  WITH refSpan
  MATCH (refEntry:RefEntry {id: refSpan.ref_id})
  MERGE (refSpan)-[:has_refentry]->(refEntry)
",{batchSize: 5, iterateList: true, parallel:false, concurrency:5});
