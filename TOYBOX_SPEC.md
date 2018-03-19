# Specifications and Proof of Concept work for the AAC Toybox

#### Toybox Specifications

As part of the AAC, we're looking to create a generalizable framework for building visualizations of the data.  We refer to these visualizations as *toys*, and they will be displayed in a section of each entity's page called the *toybox*.  

Each toy will consist of:

* A SPARQL query, designed to be executed against the AAC Triplestore.
* A JSON-LD for the results of the query.
* A javascript function that will allow a filter score to be calculated based on item metadata, returning a boolean value.
* A javascript function that will allow a value to be computed based on the results of the query, returning a boolean value.
* A Handlebar template, with namespaced, embedded CSS, that responsively fills a single DIV, designed to be populated with the generated JSON-LD as well as the JSON-LD provided by the AAC entity. 
* A Javascript (Immediately-Invoked Function Expression)[http://benalman.com/news/2010/11/immediately-invoked-function-expression/] that returns an object with an `init()` method that, when called with the ID of the div as the only parameter, initializes the widget.

The browse application will choose toys based on the following algorithm:

1. Each toy will have an intrinsic ranking.  Higher ranked toys go first.
2. Each toy will have a filter score, calculatable from the item's metadata (after normalization). Toys that return false will be skipped
3. Each toy will have a sparql query and a JSON-LD frame.  The query will be executed and framed.
4. Each toy will have a score calculatable from the resulting framed JSON-LD document. Toys that return false will be skipped.
5. Continue until out of toys or at least N toys are not skipped.

This will take place in a dedicated phase of the site design, which is detailed below.

#### AAC Site Building Design Proposal

When building the site, we will perform the following operations in order:

1. Get **Core Entities** from **Triple Store**
    - add entities to **Entity Queue**

2. While there are entries in the **Entity Queue**, pop an entry and:
    - Skip if the entity exists in the **Document Queue**
    - Run each query for that entity type, and save the result into the **Entity Cache**
    - Add the entity ID to the **Document Queue**
    - Add any entities found to the **Entity Queue**

3. For each document in the **Document Queue**, pop an entry and:
    - For each ID, replace the ID with the limited result for that entity.
    - Generate the metatdata for the document
    - **Compute the toybox lists**
    - **Run the appropriate SPARQL for the toybox data**
    - **Frame the toybox results**
    - **Add the toybox metadata to the document**
    - Convert the document to JSON-LD
    - Save the document to its persistent location
    - Add the entity to the **Generation List**

4. For each entity on the Generation List, pop and entry and:
    A.- Generate the IIIF subdocument if needed
    B.- Generate the HTML.
    C.- Generate the search index.
 
5. Generate the static content pages, CSS, and javascript of the site.

6. Upload the generated HTML and IIIF to the hosting service.
