// @flow
type D3Dom = () => () => mixed
type colorObject = Array<{ closest: string, color: string}>

const Color = require("color-js")
const d3 = require("d3")

class Palette {

  colors: colorObject
  height: number
  width: number
  svg: D3Dom
  selectionLine: D3Dom
  bigCircle: D3Dom
  diamond: D3Dom

  constructor(palette: colorObject) {
    // Select the DOM element
    const parent = d3.select("#palette_viz")

    // Set up the margins
    /* eslint-disable no-multi-spaces */
    const bbox   = parent.node().getBoundingClientRect()
    const margin = {top: 0, right: 50, bottom: 0, left: 0}
    this.width   = +bbox.width - margin.left - margin.right
    this.height  = +bbox.height - margin.top - margin.bottom
    /* eslint-enable no-multi-spaces */


    this.svg = parent.select("svg").append("g")
        .attr("transform", `translate(${margin.left},${margin.top})`)

    this.colors = palette

    this.svg.append("line")
        .attr("x1", 0)
        .attr("x2", this.width-30)
        .attr("y1", this.height/2)
        .attr("y2", this.height/2)
        .attr("stroke", "#fff")

    this.selectionLine = this.svg.append("line")
      .attr("x1", 10)
      .attr("x2", 10)
      .attr("y1", this.height*0.25)
      .attr("y2", this.height*0.75)
      .attr("stroke", "#fff")

    this.bigCircle = this.svg.append("circle")
        .attr("cx", this.width-30)
        .attr("cy", this.height/2)
        .attr("r", 30)
        .attr("stroke", "#ffffff")

    this.diamond = this.svg.append("g")
    this.diamond.append("rect")
        .attr("width", 15)
        .attr("height", 15)
        .attr("y", -7.5)
        .attr("x", -7.5)
        .attr("stroke", "#ffffff")
        .attr("fill", "990000")
  }

  update(selectedColorIndex: number) {
      // Get the new color
    const selectedColor = this.colors[selectedColorIndex].color
    const c = Color(selectedColor)

    // Handle updating the graphics
    const circle = this.svg.selectAll(".smallCircle").data(this.colors)
    circle.enter()
        .append("circle")
        .classed("smallCircle", true)
        .attr("r", 10)
        .attr("cy", this.height/2)
        .attr("cx", (d, i) => i*30+10)
        .attr("fill", d => d.color)
        .attr("stroke", "#ffffff")
        .attr("cursor", "pointer")
        .on("click", (d, i) => this.update(i))
      .merge(circle)
        .attr("visibility", (d, i) => (i === selectedColorIndex ? "hidden" : "visible"))

    this.diamond.attr("transform", `translate(${selectedColorIndex*30+10},${this.height/2}) rotate(45) `)
    this.diamond.select("rect").attr("fill", selectedColor)

    this.bigCircle.transition()
      .attrTween("fill", () => d3.interpolateHcl(this.bigCircle.attr("fill"), selectedColor))

    this.selectionLine.transition()
      .attr("x1", selectedColorIndex*30+10)
      .attr("x2", selectedColorIndex*30+10)

    // Handle updating the data display
    const rgb = d3.select("#palette-rgb-table")
    const r = c.getRed()
    const g = c.getGreen()
    const b = c.getBlue()

    rgb.select(".red .value").text(r*255)
    rgb.select(".blue .value").text(b*255)
    rgb.select(".green .value").text(g*255)
    rgb.select(".hex .value").text(c.toCSS())


    const cymk = d3.select("#palette-cymk-table")
    const k = 1-Math.max(r, g, b)
    const cyan = (1-r-k) / (1-k)
    const y = (1-b-k) / (1-k)
    const m = (1-g-k) / (1-k)
    cymk.select(".cyan .value").text(Math.round(cyan*100))
    cymk.select(".magenta .value").text(Math.round(m*100))
    cymk.select(".yellow .value").text(Math.round(y*100))
    cymk.select(".black .value").text(Math.round(k*100))
  }
}

module.exports = Palette