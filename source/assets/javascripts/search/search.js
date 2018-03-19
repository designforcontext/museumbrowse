// @flow

import elasticsearch from "elasticsearch";
import $ from "jquery";
import type { SearchHit, SearchResults } from "./search_types";
import MetadataHelpers from "./metadata_helpers";

class Search {
  // Instance Variables (with types)
  // ---------------------------------------------------------------------------
  searchDomElement: string;
  elasticsearchClient: any;
  resultsPerPage: number;
  lastSearchString: string;
  currentPageNumber: number;

  // ---------------------------------------------------------------------------
  constructor(
    host: string,
    searchDomElement: string,
    resultsPerPage: number = 25
  ) {
    this.searchDomElement = searchDomElement;
    this.resultsPerPage = resultsPerPage;

    const options = { host };
    this.elasticsearchClient = new elasticsearch.Client(options);
  }

  // ---------------------------------------------------------------------------
  searchFromParams(): void {
    const queryRegex = new RegExp("[?&]q=([^&#]*)");
    const pageRegex = new RegExp("[?&]p=([^&#]*)");
    const creatorRegex = new RegExp("[?&]creator=([^&#]*)");
    const ownerRegex = new RegExp("[?&]owner=([^&#]*)");
    const results = queryRegex.exec(window.location.href);
    const page = pageRegex.exec(window.location.href);
    const creator = creatorRegex.exec(window.location.href);
    const owner = ownerRegex.exec(window.location.href);
    const pageNum = page == null ? 1 : page[1];

    const opts = {};
    if (creator) {
      opts.creator = creator[1];
    }
    if (owner) {
      opts.owner = owner[1];
    }

    if (results != null) {
      this.search(results[1], pageNum, opts);
    } else {
      Search.noResults(this.searchDomElement);
    }
  }

  // ---------------------------------------------------------------------------
  search(
    searchTerm: string,
    page: number = 1,
    options: SearchOptions = {}
  ): void {
    Search.setPlaceholder(searchTerm);
    this.lastSearchString = searchTerm;
    this.currentPageNumber = Number(page);
    const startVal: number = (page - 1) * this.resultsPerPage;

    var query_parts = [];
    var filter_parts = [];
    const text_query = {
      multi_match: {
        query: decodeURI(searchTerm),
        type: "best_fields",
        fields: ["label", "_all"],
        fuzziness: "AUTO",
        operator: "and"
      }
    };

    query_parts.push(text_query);

    if (options.creator) {
      const creator_query = {
        term: { "produced_by.carried_out_by.id": options.creator }
      };
      filter_parts.push(creator_query);
    }
    if (options.owner) {
      const owner_query = {
        filter: { term: { "current_owner.id": options.owner } }
      };
      filter_parts.push(owner_query);
    }

    const searchObj = {
      size: this.resultsPerPage,
      from: startVal,
      body: {
        query: {
          bool: {
            must: query_parts,
            should: [
              {
                match: {
                  type: {
                    query: "Actor",
                    boost: 1.2
                  }
                }
              },
              { exists: { field: "subject_of.value", boost: 4 } },
              { exists: { field: "description", boost: 4 } }
            ],
            filter: filter_parts
          }
        }
      }
    };

    this.elasticsearchClient
      .search(searchObj)
      .then(this.update.bind(this), error => console.trace(error.message));
  }

  // ---------------------------------------------------------------------------
  update(results: SearchResults): void {
    console.log(results);
    if (Array.isArray(results.hits.hits) && results.hits.hits.length) {
      const items: Array<string> = results.hits.hits.map(val =>
        Search.generateSearchResult(val)
      );

      let resultsText = decodeURI(this.lastSearchString);
      resultsText += `<br><span class='secondary'> (${
        results.hits.total
      } results found)</span>`;

      $(`#${this.searchDomElement} h1`).html(resultsText);
      $(`#${this.searchDomElement} .pagination`).html(
        this.paginationLinks(this.currentPageNumber, results.hits.total)
      );
      if (items.length < 5) {
        $(`#${this.searchDomElement} header .pagination`).hide();
      }
      $(`#${this.searchDomElement} .search_results`).replaceWith(
        items.join("\n")
      );
    } else {
      Search.noResults(this.searchDomElement);
    }
  }

  // ---------------------------------------------------------------------------
  static generateImage(data, entityUrl: string): string {
    let img =
      "<img class='img-thumbnail img-placeholder' alt='' src='/images/page_elements/no_image.png'>";
    if (data.representation) {
      let imgObject = "";
      if (Array.isArray(data.representation)) {
        imgObject = data.representation[0];
      } else {
        imgObject = data.representation;
      }
      img = `
        <a href='${entityUrl}.html'>
          <img class="img-thumbnail" src="${imgObject.id}" alt="">
        </a>
      `;
    }
    return img;
  }

  // ---------------------------------------------------------------------------
  static getObjectDimensions(data): string | null {
    if (data.referred_to_by) {
      const dims = MetadataHelpers.filterByClassification(
        data.referred_to_by,
        "aat:300266036"
      );
      return MetadataHelpers.firstOrOnly(dims);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  static getObjectMedium(data): string | null {
    // if (data.medium) {
    //   const medium = MetadataHelpers.filterByClassification(
    //     data.referred_to_by,
    //     "aat:300264237"
    //   );
    //   return MetadataHelpers.firstOrOnly(medium);
    // }
    return data.medium;
  }

  // ---------------------------------------------------------------------------
  static getObjectType(data): string | null {
    if (data.classified_by) {
      const objectType = MetadataHelpers.filterByPurpose(
        data.classified_by,
        "aat:300179869"
      );
      const objectTypeString = MetadataHelpers.firstOrOnly(objectType, "label");
      if (objectTypeString) {
        return objectTypeString;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  static getNumberOfWorks(created_count): string {
    if (created_count >= 1) {
      return `${created_count} Objects`;
    } else if (created_count == 1) {
      return "One Object";
    } else {
      return "No Objects";
    }
  }

  // ---------------------------------------------------------------------------
  static getDescription(data) {
    if (data.type === "ManMadeObject" && data.subject_of) {
      const descArray = MetadataHelpers.filterByClassification(
        data.subject_of,
        "aat:300080091"
      );
      const subject = MetadataHelpers.firstOrOnly(descArray);
      return MetadataHelpers.truncateSentences(subject, 2) || "";
    } else if (typeof data.description === "string") {
      return MetadataHelpers.truncateSentences(data.description, 2);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  static getCreationYear(data) {
    if (data && data.timespan && data.timespan.label) {
      return data.timespan.label;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  static generateSearchResult(hit: SearchHit): string {
    const data = hit["_source"];
    const entityUrl = hit["_id"];
    try {
      const img = Search.generateImage(data, entityUrl);
      const ownerName = data.current_owner ? data.current_owner.label : null;
      const numberOfWorks = Search.getNumberOfWorks(data["created_count"]);
      const production = MetadataHelpers.firstOrOnlyRaw(data.produced_by);
      const creator = production
        ? MetadataHelpers.firstOrOnlyRaw(production.carried_out_by)
        : null;
      const creatorName = creator
        ? MetadataHelpers.firstOrOnlyRaw(creator.label)
        : null;
      const creationYear = production
        ? Search.getCreationYear(production)
        : null;
      const objectMedium = Search.getObjectMedium(data);
      const objectType = Search.getObjectType(data);
      const objectDims = Search.getObjectDimensions(data);
      const headerText = Array.isArray(data.label) ? data.label[0] : data.label;
      const description = Search.getDescription(data);

      //
      let content = "";

      // Content block for Objects
      if (data.type === "ManMadeObject") {
        let creationYearHTML = creationYear
          ? `<span class='year'>${creationYear}</span>`
          : "";
        let creatorNameHTML = creatorName
          ? `<span class="creator">${creatorName}</span>`
          : "";

        content = `
          <h2>
            <span class=result_type>Object</span>
            <a href='${hit["_id"]}.html'>${headerText}</a> 
          </h2>
          <div>
            ${[creationYearHTML, creatorNameHTML]
              .filter(n => n)
              .join("<span class='item_spacer'> • </span>")}
          </div>
          <div >
            ${[objectType, objectMedium]
              .filter(n => n)
              .join("<span class='item_spacer'> • </span>")}
          </div>
          <div class='second_block'>${ownerName}</div>
        `;
      } else {
        // Content block for People
        content = `
          <h2>
            <span class=result_type>Creator</span>
            <a href='${hit["_id"]}.html'>${headerText}</a> 
          </h2>

          <div> ${numberOfWorks}</div>
        `;
      }

      return `
      <div class='row result'>
        <div class='col-2 img-holder'>
          ${img}
        </div>
        <div class="col search_metadata">
          ${content}
        </div>
        <div class="col">
          ${description || ""}
        </div>
      </div>`;
    } catch (e) {
      console.log("error:", e);
      return JSON.stringify(data);
    }
  }

  // ---------------------------------------------------------------------------
  paginationLinks(page: number, total: number): string {
    const isFirstPage = page === 1;
    const lastPageNum = Math.ceil(total / this.resultsPerPage);
    const isLastPage = this.currentPageNumber === lastPageNum;

    const first = isFirstPage
      ? this.pageLink(1, "&laquo;")
      : this.pageLink(this.currentPageNumber - 1, "&laquo;");
    const last = isLastPage
      ? this.pageLink(lastPageNum, "&raquo;")
      : this.pageLink(this.currentPageNumber + 1, "&raquo;");
    let before_current = [];
    const current = this.pageLink(page);
    let after_current = [];

    for (let i = 1; i < page; i += 1) {
      before_current.push(this.pageLink(i));
    }
    for (let i = page + 1; i <= lastPageNum; i += 1) {
      after_current.push(this.pageLink(i));
    }

    if (before_current.length > 3) {
      const first = before_current.slice(0, 1);
      const remainder = 6 - Math.min(after_current.length, 3);
      before_current = before_current.slice(-remainder);
      before_current.unshift(this.pageLink(page, "..."));
      before_current.unshift(first);
    }

    if (after_current.length > 3) {
      const last = after_current.slice(-1);
      const remainder = 6 - Math.min(before_current.length, 3);
      after_current = after_current.slice(0, remainder);
      after_current.push(this.pageLink(page, "..."));
      after_current.push(last);
    }
    const content = [
      first,
      ...before_current,
      current,
      ...after_current,
      last
    ].join("");
    return `
      <nav aria-label="Search Result Pages">
        <ul class='pagination pagination-sm'>
          ${content}
        </ul>
      </nav>`;
  }

  // ---------------------------------------------------------------------------
  pageLink(page: number, text: string | null = null): string {
    let className = "";
    if (page === this.currentPageNumber) {
      className = text ? "disabled" : "active";
    }
    return `
      <li class="page-item ${className}">
        <a class='page-link' href='/search.html?q=${
          this.lastSearchString
        }&p=${page}'>
          ${text || String(page)}
        </a>
      </li>`;
  }

  // ---------------------------------------------------------------------------
  static noResults(element: string) {
    const str = `
      <div class='row'>
        <div class='col no_results'>
          No Results Found.
        </div>
      </div>`;

    $(`#${element} .search_results`).replaceWith(str);
  }

  // ---------------------------------------------------------------------------
  static setPlaceholder(value: string): void {
    $("#searchbox").attr("placeholder", decodeURI(value));
  }

  // ---------------------------------------------------------------------------
  static executeSearch(e) {
    e.preventDefault();
    if (e.keyCode === undefined || e.keyCode === 13) {
      const search = $("#searchbox").val();
      window.location.assign(`/search.html?q=${search}`);
    }
  }
}

module.exports = Search;
