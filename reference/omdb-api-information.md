Title: OMDb API - The Open Movie Database

URL Source: https://www.omdbapi.com/

Published Time: Mon, 28 Jul 2025 21:19:21 GMT

Markdown Content:
OMDb API - The Open Movie Database

---

The API key is `342b31d6`

It is used in the url as such:

https://www.omdbapi.com/?i=tt3896198&apikey=342b31d6

Response:

```json
{"Title":"Guardians of the Galaxy Vol. 2","Year":"2017","Rated":"PG-13","Released":"05 May 2017","Runtime":"136 min","Genre":"Action, Adventure, Comedy","Director":"James Gunn","Writer":"James Gunn, Dan Abnett, Andy Lanning","Actors":"Chris Pratt, Zoe Saldaña, Dave Bautista","Plot":"The Guardians struggle to keep together as a team while dealing with their personal family issues, notably Star-Lord's encounter with his father, the ambitious celestial being Ego.","Language":"English","Country":"United States","Awards":"Nominated for 1 Oscar. 15 wins & 60 nominations total","Poster":"https://m.media-amazon.com/images/M/MV5BNWE5MGI3MDctMmU5Ni00YzI2LWEzMTQtZGIyZDA5MzQzNDBhXkEyXkFqcGc@._V1_SX300.jpg","Ratings":[{"Source":"Internet Movie Database","Value":"7.6/10"},{"Source":"Rotten Tomatoes","Value":"85%"},{"Source":"Metacritic","Value":"67/100"}],"Metascore":"67","imdbRating":"7.6","imdbVotes":"802,014","imdbID":"tt3896198","Type":"movie","DVD":"N/A","BoxOffice":"$389,813,101","Production":"N/A","Website":"N/A","Response":"True"}
```

===============

[OMDb API](https://www.omdbapi.com/#top)

*   [Usage](https://www.omdbapi.com/#usage)
*   [Parameters](https://www.omdbapi.com/#parameters)
*   [Examples](https://www.omdbapi.com/#examples)
*   [Change Log](https://www.omdbapi.com/#changeLog)
*   [API Key](https://www.omdbapi.com/apikey.aspx)


OMDb API
========

The Open Movie Database

The OMDb API is a RESTful web service to obtain movie information, all content and images on the site are contributed and maintained by our users. 


Usage
=====

Send all data requests to:

http://www.omdbapi.com/?apikey=[yourkey]&

Poster API requests:

http://img.omdbapi.com/?apikey=[yourkey]&

Parameters
==========

#### By ID or Title

| Parameter | Required | Valid Options | Default Value | Description |
| --- | --- | --- | --- | --- |
| i | Optional* |  | <empty> | A valid IMDb ID (e.g. tt1285016) |
| t | Optional* |  | <empty> | Movie title to search for. |
| type | No | movie, series, episode | <empty> | Type of result to return. |
| y | No |  | <empty> | Year of release. |
| plot | No | short, full | short | Return short or full plot. |
| r | No | json, xml | json | The data type to return. |
| callback | No |  | <empty> | JSONP callback name. |
| v | No |  | 1 | API version (reserved for future use). |
*Please note while both "i" and "t" are optional at least one argument is required.

* * *

#### By Search

| Parameter | Required | Valid options | Default Value | Description |
| --- | --- | --- | --- | --- |
| s | Yes |  | <empty> | Movie title to search for. |
| type | No | movie, series, episode | <empty> | Type of result to return. |
| y | No |  | <empty> | Year of release. |
| r | No | json, xml | json | The data type to return. |
| page New! | No | 1-100 | 1 | Page number to return. |
| callback | No |  | <empty> | JSONP callback name. |
| v | No |  | 1 | API version (reserved for future use). |
