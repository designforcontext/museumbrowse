Query to retrieve AAT ids:

```
select * {
  aat:300033618 xl:prefLabel|xl:altLabel ?l.
  ?l dct:language gvp_lang:en; gvp:term ?term.
  optional {?l gvp:termType ?type}
  optional {?l gvp:termPOS ?pos}
}

OR (simpler)

select * {
  aat:300033618 xl:prefLabel|xl:altLabel ?l.
  ?l dct:language gvp_lang:en; gvp:term ?term; gvp:termType ?type; gvp:termPOS ?pos; 
}
```

# MOST COMMON TITLES

```
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
PREFIX crm: <http://www.cidoc-crm.org/cidoc-crm/>
SELECT ?title (COUNT(?title) as ?count) WHERE {
  ?e rdfs:label ?title;
     a crm:E22_Man-Made_Object
}
GROUP BY ?title

ORDER BY DESC(?count)

LIMIT 100 
```

