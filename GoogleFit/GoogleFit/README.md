# GoogleFit Data Connector
The GoogleFit M extension allows you to connect to GoogleFit using the OAuth 2.0 protocol authentication flow.

This project was adapted from:
- https://github.com/Microsoft/DataConnectors
- https://github.com/Kjonge/PowerBIStravaConnector


## Steps to start using GoogleFit Connector:



1. Create a new project at https://console.developers.google.com/.


2. Under the "Credentials" tab, select "OAuth Client ID" and choose the application type as "Web application"


3. Specify the "Authorized redirect URIs" as: https://oauth.powerbi.com/views/oauthredirect.html


4. Under the "Dashboard" tab, enable the "Fitness API"


5. Clone or download this project and open the solution in Visual Studio


6. Add the `client_id` and `client_secret` from step 2 to the corresponding files


7. Build the project to produce an extension file .mez (\bin\Debug)


8. Copy the extension file into [My Documents]\Microsoft Power BI Desktop\Custom Connectors directory


9. Enable the Custom data connectors preview feature in Power BI Desktop (under File | Options and settings | Custom data connectors)


10. Restart Power BI Desktop