# TSGIS

[here](https://semnil.com/game/index.html)

### Require services
- Steam Store Search API  
  `https://store.steampowered.com/api/storesearch/` (no auth required)

- AWS API Gateway  
  for Lambda Proxy

- AWS Lambda  
  - [steamGame](https://github.com/semnil/TSGIS/tree/master/lambda/steamGame)
  - [historySteamGame](https://github.com/semnil/TSGIS/tree/master/lambda/historySteamGame)

### Migration notes

Originally backed by Google Custom Search JSON API. Migrated to the Steam Store Search API in 2026-04; see [docs/migration-from-google-custom-search.md](docs/migration-from-google-custom-search.md) for background and rationale.
