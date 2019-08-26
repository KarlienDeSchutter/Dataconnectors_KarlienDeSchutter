// This file contains your Data Connector logic
section Teamleader_API_Connection;

client_id = Text.FromBinary(Extension.Contents("client_id"));
client_secret = Text.FromBinary(Extension.Contents("client_secret"));
redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 600;
windowHeight = 1000;

[DataSource.Kind="Teamleader_API_Connection", Publish="Teamleader_API_Connection.Publish"]
shared Teamleader_API_Connection.Contents = Value.ReplaceType((url as text)  as table =>
    let
        source = #table({"Name", "Data", "ItemKind", "ItemName", "IsLeaf"}, {
            { "Companies", GetCompanies(url), "Table", "Table", true },
            { "Contacts", GetContacts(url),"Table","Table",true},
            { "Deals", GetDeals(url), "Table", "Table", true },
            { "DealPhases", GetDealPhases(url), "Table", "Table", true },
            { "DealSources", GetDealSources(url), "Table", "Table", true },
            { "Departments", GetDepartments(url),"Table", "Table", true  },
            { "LostReasons", GetLostReasons(url), "Table", "Table", true },
            { "Users", GetUsers(url), "Table", "Table", true }
        }),
        navTable = Table.ToNavigationTable(source, {"Name"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        navTable , type function (url as Uri.Type) as any);



[DataSource.Kind="Teamleader_API_Connection"]
shared Teamleader_API_Connection.GetQuery =
    Value.ReplaceType(
        (url as text, optional options as nullable record ) =>
            let
                content = Web.Contents(url,options),
                json = Json.Document(content)
            in
                json
        , type function (url as Uri.Type,optional options as nullable record ) as any
    );
 

[DataSource.Kind="Teamleader_API_Connection"]
shared Teamleader_API_Connection.MyUser =
     Value.ReplaceType(
        (url as text) =>
            let
                content = Web.Contents(url & "users.me"),
                json = Json.Document(content)
            in
                json
        , type function (url as Uri.Type ) as any
    );

[DataSource.Kind="Teamleader_API_Connection"]
shared Teamleader_API_Connection.GetCurrentApiKey =
 Value.ReplaceType(
        (url as text) =>
     let
         apiKey = Extension.CurrentCredential()
    in 
        apiKey
    , type function (url as Uri.Type ) as any
    );
  

GetPagedList = (url as text, query as text, optional previousPagenumber as number, optional combinedPages as list) =>
    let
        _previousPagenumber = if previousPagenumber = null then 1 else previousPagenumber,
        _nextPagenumber = _previousPagenumber + 1,
        GetDepartmentsPage = (url as text,optional previousPagenumber as number) =>
            let
                _previousPagenumber = if previousPagenumber = null then 1 else previousPagenumber,
                content = Web.Contents(url & query,[Content = Json.FromValue([page = [size = 100, number = _previousPagenumber]])]),
                json = Json.Document(content)[data]
            in
                json,
        _previousPage = if _previousPagenumber = 1 then GetDepartmentsPage(url,1) else combinedPages,
        _nextPage = try GetDepartmentsPage(url,_nextPagenumber) otherwise null,
        _combinedPages = if List.Count(_nextPage) <> 0 then @GetPagedList(url,query,_nextPagenumber,List.Combine({_previousPage,_nextPage})) else _previousPage
    in
        _combinedPages;

GetPagedTable = (url as text, query as text) =>
    let
        Source = GetPagedList(url,query),
        #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    in
        #"Converted to Table";


GetContacts = (url as text) =>
    let
        content = GetPagedTable(url, "contacts.list"),
        #"Expanded Column1" = Table.ExpandRecordColumn(content, "Column1", {"id", "first_name", "last_name", "emails", "salutation", "telephones", "website", "gender", "birthdate", "iban", "bic", "national_identification_number", "language", "payment_term", "invoicing_preferences", "added_at", "updated_at", "web_url", "primary_address", "tags"}),
        Custom1 = Table.AddColumn(#"Expanded Column1","info", each Teamleader_API_Connection.GetQuery(url & "contacts.info",[Query=[id=_[id]]]))
    in
        Custom1;

GetDepartments = (url as text) =>
    let
        content = Web.Contents(url & "departments.list"),
        json = Json.Document(content)[data],
        #"Converted to Table" = Table.FromList(json, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
        #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"id", "name", "currency", "vat_number"}),
        details = Table.AddColumn(#"Expanded Column1","info", each Teamleader_API_Connection.GetQuery(url & "departments.info",[Query=[id=_[id]]]))
    in
        details;

GetDeals = (url as text) =>
    let
        content = GetPagedTable(url, "deals.list"),
        //#"Expanded Column1" = Table.ExpandRecordColumn(content, "Column1", {"id", "first_name", "last_name", "emails", "salutation", "telephones", "website", "gender", "birthdate", "iban", "bic", "national_identification_number", "language", "payment_term", "invoicing_preferences", "added_at", "updated_at", "web_url", "primary_address", "tags"}),
        #"Expanded Column1" = Table.ExpandRecordColumn(content, "Column1", {"id", "title", "reference", "status", "lead", "department", "estimated_value", "estimated_closing_date", "estimated_probability", "current_phase", "responsible_user", "closed_at", "source", "created_at", "updated_at", "web_url"}, {"id", "title", "reference", "status", "lead", "department", "estimated_value", "estimated_closing_date", "estimated_probability", "current_phase", "responsible_user", "closed_at", "source", "created_at", "updated_at", "web_url"}),
        #"Expanded lead" = Table.ExpandRecordColumn(#"Expanded Column1", "lead", {"customer", "contact_person"}, {"lead.customer", "lead.contact_person"}),
        #"Expanded lead.customer" = Table.ExpandRecordColumn(#"Expanded lead", "lead.customer", {"type", "id"}, {"lead.customer.type", "lead.customer.id"}),
        #"Expanded lead.contact_person" = Table.ExpandRecordColumn(#"Expanded lead.customer", "lead.contact_person", {"type", "id"}, {"lead.contact_person.type", "lead.contact_person.id"}),
        #"Expanded department" = Table.ExpandRecordColumn(#"Expanded lead.contact_person", "department", {"type", "id"}, {"department.type", "department.id"}),
        #"Expanded estimated_value" = Table.ExpandRecordColumn(#"Expanded department", "estimated_value", {"amount", "currency"}, {"amount", "currency"}),
        #"Expanded current_phase" = Table.ExpandRecordColumn(#"Expanded estimated_value", "current_phase", {"type", "id"}, {"current_phase.type", "current_phase.id"}),
        #"Expanded responsible_user" = Table.ExpandRecordColumn(#"Expanded current_phase", "responsible_user", {"type", "id"}, {"responsible_user.type", "responsible_user.id"}),
        #"Expanded source" = Table.ExpandRecordColumn(#"Expanded responsible_user", "source", {"type", "id"}, {"source.type", "source.id"}),
        Custom1 = Table.AddColumn( #"Expanded source","info", each Teamleader_API_Connection.GetQuery(url & "deals.info",[Query=[id=_[id]]]))
    in
        Custom1;

GetLostReasons = (url as text) =>
    let
        content = GetPagedTable(url, "lostReasons.list"),
        #"Expanded Column1" = Table.ExpandRecordColumn( content, "Column1", {"id","name"})
    in
        #"Expanded Column1";

GetDealPhases = (url as text) =>
    let
        content = GetPagedTable(url, "dealPhases.list"),
        #"Expanded Column1" = Table.ExpandRecordColumn( content, "Column1",{"id", "name", "actions", "status"} )
    in
        #"Expanded Column1";

GetDealSources = (url as text) =>
    let
        content = GetPagedTable(url, "dealSources.list"),
        #"Expanded Column1" = Table.ExpandRecordColumn( content, "Column1",{"id", "name"} )
    in
        #"Expanded Column1";

GetCompanies = (url as text) =>
    let
        content = GetPagedTable(url, "companies.list"),
        #"Expanded Column1" = Table.ExpandRecordColumn(content, "Column1", {"id", "name", "business_type", "vat_number", "national_identification_number", "emails", "telephones", "website", "iban", "bic", "language", "payment_term", "preferred_currency", "invoicing_preferences", "added_at", "updated_at", "web_url", "primary_address", "responsible_user", "tags"}),
        Custom1 = Table.AddColumn(#"Expanded Column1","info", each Teamleader_API_Connection.GetQuery(url & "companies.info",[Query=[id=_[id]]]))
    in
        Custom1;

GetUsers = (url as text) =>
    let
        content = GetPagedTable(url, "users.list"),
        #"Expanded Column1" = Table.ExpandRecordColumn(content, "Column1", {"id", "account", "first_name", "last_name", "email", "language", "telephones", "function", "status"}, {"id", "account", "first_name", "last_name", "email", "language", "telephones", "function", "status"} ),
        Custom1 = Table.AddColumn(#"Expanded Column1","info", each Teamleader_API_Connection.GetQuery(url & "users.info",[Query=[id=_[id]]]))
    in
        Custom1;


//create navigationtable for powerBI to read
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

// Data Source Kind description
Teamleader_API_Connection = [
    // line is needed for gateway support
    TestConnection = (dataSourcePath) => { "Teamleader_API_Connection.Contents", dataSourcePath},
    //oauth2
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

// Data Source UI publishing description

Teamleader_API_Connection.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("FormulaHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = Teamleader_API_Connection.Icons,
    SourceTypeImage = Teamleader_API_Connection.Icons
];

Teamleader_API_Connection.Icons = [
    Icon16 = { Extension.Contents("Teamleader_API_Connection16.png"), Extension.Contents("Teamleader_API_Connection20.png"), Extension.Contents("Teamleader_API_Connection24.png"), Extension.Contents("Teamleader_API_Connection32.png") },
    Icon32 = { Extension.Contents("Teamleader_API_Connection32.png"), Extension.Contents("Teamleader_API_Connection40.png"), Extension.Contents("Teamleader_API_Connection48.png"), Extension.Contents("Teamleader_API_Connection64.png") }
];




//
// OAuth2 flow definition
//
StartLogin = (resourceUrl, state, display) =>
let
        AuthorizeUrl = "https://app.teamleader.eu/oauth2/authorize?",
        QueryString = Uri.BuildQueryString([
            client_id = client_id,
            response_type = "code",
            state = state,
            redirect_uri = redirect_uri])
    in
        [
            LoginUri = AuthorizeUrl & QueryString,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = null
        ];

FinishLogin = (context, callbackUri, state) =>
    let
        parts = Uri.Parts(callbackUri)[Query],
        result = if (Record.HasFields(parts, {"error", "error_description"})) then 
                    error Error.Record(parts[error], parts[error_description], parts)
                 else
                    TokenMethod("authorization_code", "", parts[code])
    in
        result;
		
TokenMethod = (grantType, tokenField,code) =>
    let
        TokenUrl = "https://app.teamleader.eu/oauth2/access_token",
        Response = Web.Contents(TokenUrl, [
            Content = Text.ToBinary(Uri.BuildQueryString([
                client_id = client_id,
                client_secret = client_secret,
                code = code,
                grant_type = grantType,
                redirect_uri = redirect_uri,
                refresh_token = tokenField
				])),
            Headers=[#"Content-type" = "application/x-www-form-urlencoded",#"Accept" = "application/json"]]),
        Parts = Json.Document(Response)
    in
        Parts;

Refresh =  (resourceUrl, refresh_token) => TokenMethod("refresh_token",refresh_token,"");


Value.WaitFor = (producer as function, interval as function, optional count as number) as any =>
    let
        list = List.Generate(
            () => {0, null},
            (state) => state{0} <> null and (count = null or state{0} < count),
            (state) => if state{1} <> null then {null, state{1}} else {1 + state{0}, Function.InvokeAfter(() => producer(state{0}), interval(state{0}))},
            (state) => state{1})
    in
        List.Last(list);