# TSGIS

[here](https://semnil.com/game/index.html)

### Require services
- Google Custom Search API

- AWS API Gateway  
  for Lambda Proxy

- AWS Lambda  
  - [steamGame](https://github.com/semnil/TSGIS/tree/master/lambda/steamGame)
  - [historySteamGame](https://github.com/semnil/TSGIS/tree/master/lambda/historySteamGame)

- AWS Key Management Service  
  for Google Custom Search API environment values encryption
  - ENCRYPTED_GOOGLE_APP_ID
  - ENCRYPTED_GOOGLE_API_KEY
