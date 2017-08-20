section GoogleFit;

//
// 1. Register a new Web application at https://console.developers.google.com/
// 2. Specify the redirect url as: https://oauth.powerbi.com/views/oauthredirect.html
// 3. Get your client_id and client_secret and add them to the corresponding files.
//

client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = Text.FromBinary(Extension.Contents("client_secret"));
authorize_url = "https://accounts.google.com/o/oauth2/auth";
token_url = "https://accounts.google.com/o/oauth2/token";
redirect_url = "https://oauth.powerbi.com/views/oauthredirect.html";

// Base URL
dataSources_url = "https://www.googleapis.com/fitness/v1/users/me/dataSources/";
// DataSet URL. Returns a dataset containing all data points between epoch and 2019686400000000000 nanoseconds (01/01/2034 00:00:00)
dataSet_url = "/datasets/0-2019686400000000000";

// To request access using OAuth 2.0, your application needs the scope information
scope_prefix = "https://www.googleapis.com/auth/";
scopes = {
    "fitness.activity.read",
    "fitness.body.read",
    "fitness.location.read",
    "fitness.nutrition.read"
};
Value.IfNull = (a, b) => if a <> null then a else b;

GetScopeString = (scopes as list, optional scopePrefix as text) as text =>
    let
        prefix = Value.IfNull(scopePrefix, ""),
        addPrefix = List.Transform(scopes, each scopePrefix & _),
        asText = Text.Combine(addPrefix, " ")
    in
        asText;

page_size = 200;
windowWidth = 1200;
windowHeight = 1000;

//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates 
// them with the specified Data Source Kind. The Data Source Kind is used when determining which 
// credentials to use during evaluation. Credential matching is done based on the function's parameters. 
// All data source functions associated to the same Data Source Kind must have a matching set of required 
// function parameters, including type, name, and the order in which they appear. 

[DataSource.Kind="GoogleFit", Publish="GoogleFit.UI"]
shared GoogleFit.Contents = () => GoogleFitNavTable(dataSources_url) as table;     

//
// Navigation functions
//
GoogleFitNavTable = (url) as table =>
    let
        content = Web.Contents(dataSources_url),
        json = Json.Document(content),
        entitiesAsTable = Table.FromList(json[dataSource], Splitter.SplitByNothing(), null, null, ExtraValues.Error),      

        // Add dataStreamId column
        dataStream = Table.ExpandRecordColumn(entitiesAsTable, "Column1", {"dataStreamId"}),
        dataStreamRenamed = Table.RenameColumns(dataStream, {{"dataStreamId", "Name"}}),

        // Add Data column
        withData = Table.AddColumn(dataStreamRenamed, "Data", each GoogleFit.Feed(dataSources_url & [Name] & dataSet_url)),

        // Add ItemKind and ItemName as fixed text values
        withItemKind = Table.AddColumn(withData, "ItemKind", each "Table", type text),
        withItemName = Table.AddColumn(withItemKind, "ItemName", each "Table", type text),
         
        // Indicate that the node should not be expandable
        withIsLeaf = Table.AddColumn(withItemName, "IsLeaf", each true, type logical),
        
        // Generate the nav table
        navTable = Table.ToNavigationTable(withIsLeaf, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable;


GoogleFit.Feed = (url as text) =>
    let
        source = Web.Contents(url),
        json = Json.Document(source),
 
        // The response is a JSON record - the data we want is a list of records in the "point" field       
        result = if (List.IsEmpty(json[point])) then 
            null // Avoid processing empty results
        else
            GoogleFit.ParseData(json) 
    in
        result;

GoogleFit.ParseData = (json) =>
    let
        value = json[point],
        asTable = Table.FromList(value, Splitter.SplitByNothing()),
        // expand all columns from the record
        fields = Record.FieldNames(Table.FirstValue(asTable, [Empty = null])),
        expandAll = Table.ExpandRecordColumn(asTable, "Column1", fields)
    in
        expandAll;
        
//
// Data Source definition
//
GoogleFit = [
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
           Label = Extension.LoadString("AuthenticationLabel")
        ]
    ],
    Label = Extension.LoadString("DataSourceLabel")
];

//
// UI Export definition
//
GoogleFit.UI = [
    Beta = true,
    ButtonText = { Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp") },
    SourceImage = GoogleFit.Icons,
    SourceTypeImage = GoogleFit.Icons
];

GoogleFit.Icons = [
    Icon16 = { Extension.Contents("GoogleFit16.png"), Extension.Contents("GoogleFit20.png"), Extension.Contents("GoogleFit24.png"), Extension.Contents("GoogleFit32.png") },
    Icon32 = { Extension.Contents("GoogleFit32.png"), Extension.Contents("GoogleFit40.png"), Extension.Contents("GoogleFit48.png"), Extension.Contents("GoogleFit64.png") }
];

//
// Authentication functions
//
StartLogin = (resourceUrl, state, display) =>
    let
        AuthorizeUrl = authorize_url & "?" & Uri.BuildQueryString([
            client_id = client_id,  
            redirect_uri = redirect_url,  
            state = state,    
            scope = GetScopeString(scopes, scope_prefix),
            access_type = "offline",
            prompt = "consent",
            response_type = "code",
            response_mode = "query",
            login = "login"    
        ])
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_url,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
      let
        // parse the full callbackUri, and extract the Query string
        Parts = Uri.Parts(callbackUri)[Query],
        // if the query string contains an "error" field, raise an error
        // otherwise call TokenMethod to exchange our code for an access_token
        result = if (Record.HasFields(Parts, {"error", "error_description"})) then 
                    error Error.Record(Parts[error], Parts[error_description], Parts)
                 else
                    TokenMethod("authorization_code", "code", Parts[code])
    in
        result;

Refresh = (resourceUrl, refresh_token) => TokenMethod("refresh_token","refresh_token", refresh_token);

TokenMethod = (grantType, tokenField, code) =>
    let     
        queryString =[
            client_id = client_id,
            client_secret = client_secret,
            redirect_uri = redirect_url,
            grant_type = grantType
            ],

        queryWithCode = Record.AddField(queryString, tokenField, code),

        tokenResponse = Web.Contents(token_url, [
        Content = Text.ToBinary(Uri.BuildQueryString(queryWithCode)),
        Headers = [
            #"Content-type" = "application/x-www-form-urlencoded",
            #"Accept" = "application/json"
        ],
        ManualStatusHandling = {400} 
    ]),
    body = Json.Document(tokenResponse),
    
    result = if (Record.HasFields(body, {"error", "error_description"})) then 
                error Error.Record(body[error], body[error_description], body)
            else
                body
    in
       result;

//
// Common functions
//
Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;