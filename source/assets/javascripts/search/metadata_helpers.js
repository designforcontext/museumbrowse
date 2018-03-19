// @flow
import $ from "jquery"
import type {Entity} from "./search_types"

class MetadataHelpers {


  // ---------------------------------------------------------------------------
  static truncateSentences(inputString: string | null, maxSentences: number): string {
    if (!inputString) {
      return ""
    }
    const strippedString = $(`<p>${inputString}</p>`).text().trim()
    const array = strippedString.split(/\."?\s+(?=[A-Z])/)
    const arrayLength = array.length
    let outputString = array.splice(0, maxSentences).join(". ")
    if (arrayLength > maxSentences) {
      outputString += "..."
    }
    return outputString
  }

  // ---------------------------------------------------------------------------
  static filterByClassification(entity, classification: string): Entity | Entity[] {
    const arr = MetadataHelpers.makeArray(entity)
    return arr.filter(obj => MetadataHelpers.filterFunction(obj, classification, "classified_as"))
  }


  // ---------------------------------------------------------------------------
  static filterByPurpose(entity, classification: string): Entity | Entity[] | null {
    const arr = MetadataHelpers.makeArray(entity)
    const results = arr.filter(obj => MetadataHelpers.filterFunction(obj, classification, "general_purpose"))
    if (results) {
      const values = []
      results.forEach(val => values.push(val.assigned_type))
      return values
    }
    return null
  }

  // ---------------------------------------------------------------------------
  static makeArray<T>(entity: T | Array<T>): Array<T> {
    let arr = []
    if (!Array.isArray(entity)) {
      arr = [entity]
    }
    else {
      arr = entity
    }
    return arr
  }

  // ---------------------------------------------------------------------------
  static filterFunction(obj,
                        classification: string,
                        prop: string,
                        negate: boolean = false): boolean {
    let returnVal = false
    if (!obj[prop]) {
      returnVal = false
    }
    else if (Array.isArray(obj[prop])) {
      returnVal = obj[prop].includes(classification)
    }
    else if (typeof obj[prop] === "string") {
      returnVal = obj[prop] === classification
    }

    else if (typeof obj[prop] === "object") {
      if (obj[prop].id === classification) {
        returnVal = true
      }
    }

    return negate ? !returnVal : returnVal
  }

  static firstOrOnlyRaw(entity) {
    let result = null
    if (Array.isArray(entity) && entity.length) {
      result = entity[0]
    }
    else if (typeof entity === "object") {
      result = entity
    }
    else if (typeof entity === "string") {
      result = entity
    }
    return result
  }
  // ---------------------------------------------------------------------------
  static firstOrOnly(entity, key: string = "value"): string | null {
    let result = {}
    if (Array.isArray(entity) && entity.length) {
      result = entity[0]
    }
    else if (typeof entity === "object") {
      result = entity
    }
    else if (typeof entity === "string") {
      result[key] = entity
    }

    if (Array.isArray(result[key]) && result[key].length) {
      return typeof result[key][0] === "string" ? result[key][0] : null
    }
    else if (typeof result[key] === "string") {
      return result[key]
    }
    return null
  }
}

module.exports = MetadataHelpers
