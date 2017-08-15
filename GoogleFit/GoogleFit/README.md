# GoogleFit Data Connector
The GoogleFit M extension allows you to connect to GoogleFit using the OAuth 2.0 protocol authentication flow.

This project was adapted from:
- https://github.com/Microsoft/DataConnectors
- https://github.com/Kjonge/PowerBIStravaConnector


## Steps to start using GoogleFit Connector:
1. Register a new Web application at https://console.developers.google.com/


2. Specify the redirect url as: https://oauth.powerbi.com/views/oauthredirect.html


3. Clone or download this project and open the solution in Visual Studio


4. Add the `client_id` and `client_secret` to the corresponding files


5. Build the project to produce an extension file


6. Copy the extension file into [My Documents]\Microsoft Power BI Desktop\Custom Connectors directory


7. Enable the Custom data connectors preview feature in Power BI Desktop (under File | Options and settings | Custom data connectors)


8. Restart Power BI Desktop