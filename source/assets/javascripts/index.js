/* global paletteData:false */

import "babel-polyfill";
import $ from "jquery";
import Palette from "./toyboxes/palette";
import Search from "./search/search";

if (window.paletteData) {
  const p = new Palette(window.paletteData.palette);
  p.update(0);
}

if ($("#search").length) {
  window.es = new Search("https://aac-search.herokuapp.com", "search");
  // window.es = new Search(null, "search")
}

$("#search_button").click(Search.executeSearch);
$("#searchbox").keyup(Search.executeSearch);
