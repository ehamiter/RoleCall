TMDB API reference

Primary documentation is located at https://developer.themoviedb.org

API read access token:
```
eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI5YWE5YzM1ZjI1YmQzOWUxZTUzMjRkZjQ0MmFkMmIyZiIsIm5iZiI6MTc1Mzc0MTUwMS4wMzIsInN1YiI6IjY4ODdmOGJkOWYxNGY2OGViMjI0NzFmMCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.IsHuriOpF_vqsz3IdGNxafwrVB-3ZqE-yjC3cc88Hbc
```

API key:
```
9aa9c35f25bd39e1e5324df442ad2b2f
```

Swift example:

```swift
import Foundation

let url = URL(string: "https://api.themoviedb.org/3/search/person")!
var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
let queryItems: [URLQueryItem] = [
  URLQueryItem(name: "include_adult", value: "false"),
  URLQueryItem(name: "language", value: "en-US"),
  URLQueryItem(name: "page", value: "1"),
]
components.queryItems = components.queryItems.map { $0 + queryItems } ?? queryItems

var request = URLRequest(url: components.url!)
request.httpMethod = "GET"
request.timeoutInterval = 10
request.allHTTPHeaderFields = [
  "accept": "application/json",
  "Authorization": "Bearer eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI5YWE5YzM1ZjI1YmQzOWUxZTUzMjRkZjQ0MmFkMmIyZiIsIm5iZiI6MTc1Mzc0MTUwMS4wMzIsInN1YiI6IjY4ODdmOGJkOWYxNGY2OGViMjI0NzFmMCIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.IsHuriOpF_vqsz3IdGNxafwrVB-3ZqE-yjC3cc88Hbc"
]

let (data, _) = try await URLSession.shared.data(for: request)
print(String(decoding: data, as: UTF8.self))
```
