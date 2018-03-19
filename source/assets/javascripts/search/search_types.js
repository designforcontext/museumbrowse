// @flow

type Representation = { id: string}

export type SearchOptions = {
  creator?: string,
  owner?: string
}

export type Entity = {
  id: string
}
export type Type = string[] | string | Entity[]

export type LinguisticObject = {
  id: string,
  classifiedAs: Type,
  type: "LinguisticObject",
  value: string
}


type Actor = {
  label: string[] | string,
  url: string,
  type: "Actor" | "Group" | "Person",
  "toybox:created_by"?: {}[],
  representation?: Representation | Array<Representation>,
  description?: string,
}

type Production = {
  id: string,
  carried_out_by?: Actor,
  took_place_at?: {},
  timespan?: {
    label: string
  },
  type: "Production"
}

type ObjectResult = {
  label: string[] | string,
  current_owner?: {
    label: string,
    id: string
  },
  representation?: Representation | Array<Representation>,
  type: "ManMadeObject",
  subject_of?: LinguisticObject | LinguisticObject[],
  produced_by?: Production
}


export type SearchHit = {
  _id: string,
  _index: string,
  _score: number,
  _type: string,
  _source: ObjectResult | Actor,
}

export type SearchResults = {
  hits: {
    hits: Array<SearchHit>,
    total: number,
    max_score: number,
  },
  timed_out: boolean,
  took: number,
}
